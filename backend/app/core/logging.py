import logging


def configure_logging(level: str) -> None:
    """统一日志格式，避免各模块自行配置导致排障信息不一致。"""
    logging.basicConfig(
        level=level.upper(),
        format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
    )

