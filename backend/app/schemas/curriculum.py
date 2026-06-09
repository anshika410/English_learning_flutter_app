from pydantic import BaseModel

class TopicOut(BaseModel):
    id: str
    name: str
    icon: str
    color: str
    highlight_color: str
    panel_bg: str
    vocab_seeds: list[str]
    structure_targets: list[str]
