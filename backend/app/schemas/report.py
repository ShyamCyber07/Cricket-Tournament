from datetime import datetime
from typing import Optional
from pydantic import BaseModel, ConfigDict
from uuid import UUID

class ReportCreate(BaseModel):
    content_type: str  # "tournament", "match", "team", "player"
    content_id: UUID
    reason: str

class ReportResponse(BaseModel):
    id: UUID
    reporter_id: UUID
    content_type: str
    content_id: UUID
    reason: str
    status: str
    created_at: datetime
    resolved_at: Optional[datetime] = None
    resolved_by: Optional[UUID] = None

    model_config = ConfigDict(from_attributes=True)
