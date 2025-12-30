"""Async job manager for Locust load tests."""

import asyncio
import subprocess
import uuid
import os
import signal
from datetime import datetime, timedelta
from typing import Dict, Optional
from dataclasses import dataclass, field

from models import TestConfig, JobStatus, JobInfo
from metrics import JOBS_STARTED, JOBS_RUNNING, JOBS_COMPLETED, JOBS_FAILED, JOB_DURATION


# Safety limits
MAX_CONCURRENT_JOBS = 5
JOB_TTL_SECONDS = 3600  # 1 hour


@dataclass
class Job:
    """Internal job representation."""
    job_id: str
    config: TestConfig
    status: JobStatus = JobStatus.PENDING
    process: Optional[subprocess.Popen] = None
    started_at: Optional[datetime] = None
    ended_at: Optional[datetime] = None
    error: Optional[str] = None
    
    def to_info(self) -> JobInfo:
        """Convert to API response model."""
        return JobInfo(
            job_id=self.job_id,
            status=self.status,
            config=self.config,
            started_at=self.started_at.isoformat() if self.started_at else None,
            ended_at=self.ended_at.isoformat() if self.ended_at else None,
            error=self.error,
            metrics=None  # TODO: Collect from Locust
        )


class JobManager:
    """Manages async Locust job execution."""
    
    def __init__(self):
        self._jobs: Dict[str, Job] = {}
        self._lock = asyncio.Lock()
    
    @property
    def running_count(self) -> int:
        """Count of currently running jobs."""
        return sum(1 for j in self._jobs.values() if j.status == JobStatus.RUNNING)
    
    async def create_job(self, config: TestConfig) -> Job:
        """Create and start a new load test job."""
        async with self._lock:
            # Check concurrent job limit
            if self.running_count >= MAX_CONCURRENT_JOBS:
                raise ValueError(f"Maximum concurrent jobs ({MAX_CONCURRENT_JOBS}) reached")
            
            # Create job
            job_id = str(uuid.uuid4())[:8]
            job = Job(job_id=job_id, config=config)
            self._jobs[job_id] = job
            
            # Start job in background
            asyncio.create_task(self._run_job(job))
            
            return job
    
    async def _run_job(self, job: Job) -> None:
        """Execute Locust as subprocess."""
        try:
            job.status = JobStatus.RUNNING
            job.started_at = datetime.utcnow()
            JOBS_RUNNING.inc()
            JOBS_STARTED.labels(
                protocol=job.config.protocol.value,
                test_type=job.config.testType.value
            ).inc()
            
            # Build Locust command
            cmd = self._build_locust_command(job)
            
            # Set environment variables for Locust
            env = os.environ.copy()
            env.update(self._build_env(job.config))
            
            # Get the directory containing locustfile.py
            locust_dir = os.path.dirname(os.path.abspath(__file__))
            
            # Start Locust process (NON-BLOCKING)
            process = await asyncio.create_subprocess_exec(
                *cmd,
                cwd=locust_dir,
                env=env,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            job.process = process
            
            # Wait for completion or timeout
            try:
                # Wait with timeout
                await asyncio.wait_for(process.wait(), timeout=job.config.runtimeSeconds + 60)
                
                if process.returncode == 0:
                    job.status = JobStatus.COMPLETED
                    JOBS_COMPLETED.labels(
                        protocol=job.config.protocol.value,
                        status="success"
                    ).inc()
                else:
                    job.status = JobStatus.FAILED
                    # Read stderr asynchronously
                    stderr_data = await process.stderr.read()
                    stderr = stderr_data.decode() if stderr_data else ""
                    job.error = f"Exit code {process.returncode}: {stderr[:500]}"
                    JOBS_FAILED.labels(
                        protocol=job.config.protocol.value,
                        reason="exit_error"
                    ).inc()
                    
            except asyncio.TimeoutError:
                try:
                    process.kill()
                    await process.wait() # Reap zombie
                except ProcessLookupError:
                    pass
                
                job.status = JobStatus.FAILED
                job.error = "Job timed out"
                JOBS_FAILED.labels(
                    protocol=job.config.protocol.value,
                    reason="timeout"
                ).inc()
                
        except Exception as e:
            job.status = JobStatus.FAILED
            job.error = str(e)
            JOBS_FAILED.labels(
                protocol=job.config.protocol.value,
                reason="exception"
            ).inc()
            
        finally:
            job.ended_at = datetime.utcnow()
            JOBS_RUNNING.dec()
            
            if job.started_at:
                duration = (job.ended_at - job.started_at).total_seconds()
                JOB_DURATION.labels(
                    protocol=job.config.protocol.value,
                    test_type=job.config.testType.value
                ).observe(duration)
    
    def _build_locust_command(self, job: Job) -> list:
        """Build Locust CLI command."""
        return [
            "locust",
            "--headless",
            f"--users={job.config.devices}",
            f"--spawn-rate={job.config.connectRate}",
            f"--run-time={job.config.runtimeSeconds}s",
            "--only-summary",
            "-f", "locustfile.py"
        ]
    
    def _build_env(self, config: TestConfig) -> dict:
        """Build environment variables for Locust."""
        env = {
            "LOADTEST_PROTOCOL": config.protocol.value,
            "LOADTEST_BROKER_URL": config.brokerUrl,
            "LOADTEST_TEST_TYPE": config.testType.value,
            "LOADTEST_TOPIC_PATTERN": config.topicPattern,
            "LOADTEST_QOS": str(config.qos),
            "LOADTEST_RETAIN": str(config.retain).lower(),
            "LOADTEST_CLEAN_SESSION": str(config.cleanSession).lower(),
            "LOADTEST_MESSAGE_SIZE": str(config.messageSizeBytes),
            "LOADTEST_PUBLISH_RATE": str(config.publishRatePerDevice),
            "LOADTEST_USE_WEBSOCKETS": str(config.useWebSockets).lower(),
        }
        
        # Add MQTT 5.0 message expiry if configured
        if config.messageExpirySeconds:
            env["LOADTEST_MESSAGE_EXPIRY"] = str(config.messageExpirySeconds)
        
        return env
    
    async def get_job(self, job_id: str) -> Optional[Job]:
        """Get job by ID."""
        return self._jobs.get(job_id)
    
    async def stop_job(self, job_id: str) -> bool:
        """Stop a running job."""
        job = self._jobs.get(job_id)
        if not job:
            return False
        
        if job.status == JobStatus.RUNNING and job.process:
            try:
                job.process.send_signal(signal.SIGTERM)
                job.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                job.process.kill()
            
            job.status = JobStatus.STOPPED
            job.ended_at = datetime.utcnow()
            JOBS_RUNNING.dec()
            return True
        
        return False
    
    async def list_jobs(self) -> list:
        """List all jobs."""
        return [j.to_info() for j in self._jobs.values()]
    
    async def cleanup_expired(self) -> int:
        """Remove expired jobs."""
        async with self._lock:
            now = datetime.utcnow()
            expired = []
            
            for job_id, job in self._jobs.items():
                if job.ended_at and (now - job.ended_at).total_seconds() > JOB_TTL_SECONDS:
                    expired.append(job_id)
            
            for job_id in expired:
                del self._jobs[job_id]
            
            return len(expired)


# Global job manager instance
job_manager = JobManager()
