from pydantic import BaseModel


class AnonymousAuthRequest(BaseModel):
    device_id: str  # UUID generated once on the device, stored locally

    model_config = {
        "json_schema_extra": {
            "example": {
                "device_id": "3fab614c-1234-5678-abcd-1234567890ab"
            }
        }
    }


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: str
    is_new: bool  # true = first time this device registered
