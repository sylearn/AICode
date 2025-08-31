import os
import logging
from typing import List

def load_env_file(env_file: str = "config.env") -> None:
    """加载环境变量文件"""
    if not os.path.exists(env_file):
        print(f"配置文件 {env_file} 不存在")
        return
    
    with open(env_file, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith('#') and '=' in line:
                key, value = line.split('=', 1)
                os.environ[key.strip()] = value.strip()

# 加载配置文件
load_env_file()

# 环境配置
ENVIRONMENT = os.getenv('ENVIRONMENT', 'prod').lower()

# 基础配置
SAVE_PATH = os.getenv('SAVE_PATH', '')
LOG_LEVEL = getattr(logging, os.getenv('LOG_LEVEL', 'INFO').upper())

# 微信参数配置  
LISTEN_INTERVAL = int(os.getenv('LISTEN_INTERVAL', '1'))
ENABLE_FILE_LOGGER = os.getenv('ENABLE_FILE_LOGGER', 'False').lower() == 'true'
DEBUG_MODE = os.getenv('DEBUG_MODE', 'True').lower() == 'true'

# Webhook URLs
WEBHOOK_TEST_URL = os.getenv('WEBHOOK_TEST_URL', '')
WEBHOOK_PROD_URL = os.getenv('WEBHOOK_PROD_URL', '')

# 根据环境选择webhook URL
WEBHOOK_URL = WEBHOOK_TEST_URL if ENVIRONMENT == 'test' else WEBHOOK_PROD_URL

# 监听名单
def parse_list(env_var: str, default: List[str] = None) -> List[str]:
    """解析逗号分隔的环境变量为列表"""
    if default is None:
        default = []
    value = os.getenv(env_var, '')
    if not value:
        return default
    return [item.strip() for item in value.split(',') if item.strip()]

LISTEN_USERS = parse_list('LISTEN_USERS', [''])
LISTEN_GROUPS = parse_list('LISTEN_GROUPS', [''])
GROUP_PLUS_USERS = parse_list('GROUP_PLUS_USERS', [''])

# 超时设置
REQUEST_TIMEOUT = int(os.getenv('REQUEST_TIMEOUT', '300'))
IMG_DOWNLOAD_TIMEOUT = int(os.getenv('IMG_DOWNLOAD_TIMEOUT', '30'))

# 认证信息
AUTH_HEADER_KEY = os.getenv('AUTH_HEADER_KEY', '')
AUTH_HEADER_VALUE = os.getenv('AUTH_HEADER_VALUE', '')

# 错误图片路径
ERROR_IMG_PATH = os.getenv('ERROR_IMG_PATH', '')
