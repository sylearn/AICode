import logging
from wxauto import WeChat, WxParam
import wechat_msg
from config import (
    LOG_LEVEL, SAVE_PATH, LISTEN_USERS, LISTEN_GROUPS, 
    WEBHOOK_PROD_URL, LISTEN_INTERVAL, ENABLE_FILE_LOGGER, DEBUG_MODE, WEBHOOK_TEST_URL
)

# 设置日志
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger(__name__)
logger.info("开始运行")

# 使用生产环境webhook
webhook_url = WEBHOOK_PROD_URL
#webhook_url = WEBHOOK_TEST_URL
logger.info("已选择部署环境")

# 设置微信参数
WxParam.DEFAULT_SAVE_PATH = SAVE_PATH
WxParam.LISTEN_INTERVAL = LISTEN_INTERVAL
WxParam.ENABLE_FILE_LOGGER = ENABLE_FILE_LOGGER
wx = WeChat(debug=DEBUG_MODE)

# 设置全局wx对象
wechat_msg.wx = wx

# 添加监听
for user in LISTEN_USERS:
    wx.AddListenChat(nickname=user, callback=lambda msg, chat: wechat_msg.on_friend_message(msg, chat, webhook_url))
for group in LISTEN_GROUPS:
    wx.AddListenChat(nickname=group, callback=lambda msg, chat: wechat_msg.on_group_message(msg, chat, webhook_url))

# 保持程序运行
wx.KeepRunning()