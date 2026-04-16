from pydantic import BaseModel


class AnonymousAuthRequest(BaseModel):
    device_id: str  # UUID generated once on the device, stored locally


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    is_new: bool  # true = first time this device registered
