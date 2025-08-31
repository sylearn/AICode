import os
import time
from typing import Dict, Callable, Optional
from wxauto import WeChat,WxParam
from wxauto.msgs import FriendMessage,FriendQuoteMessage,FriendTextMessage,FriendImageMessage,FriendVoiceMessage,FriendVideoMessage,FriendFileMessage
from connect_n8n import send_n8n_aiagent,send_n8n_file,download_file
import logging 
from config import SAVE_PATH, LOG_LEVEL, LISTEN_USERS, LISTEN_GROUPS, GROUP_PLUS_USERS, WEBHOOK_TEST_URL, WEBHOOK_PROD_URL

# 全局变量，在main.py中会设置
wx = None 

def save_file(msg:FriendMessage)->str:
    """
        保存文件，返回文件路径
        参数：
            msg(FriendMessage): 消息对象，必须为FriendMessage类型
        返回：
            str: 文件路径
    """
    #保存文件，返回文件路径
    old_save_path=msg.download()
    #获取文件名称：命名格式为：file_path/wxauto_{msg.type}_{time.strftime('%Y%m%d%H%M%S')}.{suffix}
    old_file_name=os.path.basename(old_save_path)
    # 获取文件路径
    new_file_path=os.path.dirname(old_save_path)
    #去除wxauto_前缀
    new_file_name=old_file_name.replace("wxauto_","")
    new_save_path=os.path.join(new_file_path,new_file_name)

    #更换文件名称
    os.rename(old_save_path,new_save_path)
    #获取文件路径
    logger.info("保存路径："+new_save_path)
    return new_file_name


# ========== 模块化组件 ==========

class MessageContext:
    """消息上下文类，统一管理消息相关信息"""
    def __init__(self, msg: FriendMessage, chat: str, webhook_url: str, is_group: bool = False):
        self.msg = msg
        self.chat = chat
        self.webhook_url = webhook_url
        self.is_group = is_group
        self.chat_info = msg.chat_info()
        self.sender = msg.sender
        self.chat_name = self.chat_info.get("chat_name", "") if is_group else self.sender # 群聊时，chat_name为群聊名称，私聊时，chat_name为发送者

class PermissionManager:
    """权限管理器"""
    
    @staticmethod
    def can_save_files(sender: str, is_group: bool) -> bool:
        """检查是否可以保存文件"""
        return not is_group or sender in GROUP_PLUS_USERS
    
    @staticmethod
    def can_use_commands(sender: str, is_group: bool) -> bool:
        """检查是否可以使用命令"""
        return not is_group or sender in GROUP_PLUS_USERS
    
    @staticmethod
    def should_respond_to_group_message(msg: FriendMessage) -> bool:
        """检查是否应该响应群聊消息"""
        return msg.content.startswith("@sylearn-bot")

class MessageHandler:
    """消息处理器"""
    
    @staticmethod
    def handle_file_message(context: MessageContext) -> bool:
        """处理文件类型消息（图片、视频、文件）"""
        msg = context.msg
        
        # 检查权限
        # 如果群聊，且不在白名单中，则不处理
        if context.is_group and not PermissionManager.can_save_files(context.sender, context.is_group):
            return False
            
        # 如果消息类型为图片、视频、文件，则保存文件
        if isinstance(msg, (FriendImageMessage, FriendVideoMessage, FriendFileMessage)):
            msg_type = "图片" if isinstance(msg, FriendImageMessage) else \
                      "视频" if isinstance(msg, FriendVideoMessage) else "文件"
            logger.info(f"收到{msg_type}消息")
            
            new_file_name = save_file(msg)
            msg.quote(new_file_name)
            return True
        return False
    
    @staticmethod
    def build_content(context: MessageContext) -> str:
        """构建消息内容"""
        msg = context.msg
        content = f"Username:\n{context.sender}\n"
        
        if isinstance(msg, FriendTextMessage):
            content += f"Message:\n{msg.content}"
        elif isinstance(msg, FriendVoiceMessage):
            voice_content = msg.to_text()
            content += f"Voice:\n{voice_content}"
            logger.info(f"Voice:{voice_content}")
        elif isinstance(msg, FriendQuoteMessage):
            content += f"Message:\n{msg.content}\nQuote:\n{msg.quote_content}"
            
        return content

class CommandSystem:
    """可扩展的命令系统"""
    
    _commands: Dict[str, Callable] = {}
    
    @classmethod
    def register_command(cls, command: str, handler: Callable):
        """注册命令"""
        cls._commands[command] = handler
    
    @classmethod
    def execute_command(cls, command: str, context: MessageContext) -> bool:
        """执行命令"""
        if command in cls._commands:
            return cls._commands[command](context)
        return False
    
    @classmethod
    def has_command(cls, content: str) -> Optional[str]:
        """检查消息是否包含命令"""
        if not content.startswith("/"):
            return None
        # 检查命令是否存在
        for cmd in cls._commands.keys():
            if content.startswith(cmd):
                return cmd
        return None

def handle_ps_command(context: MessageContext) -> bool:
    """处理/ps命令"""
    msg = context.msg
    
    if not isinstance(msg, FriendQuoteMessage):
        msg.quote("ps 命令需要引用我发送的图片名称，请重新引用")
        return True
    
    quote_content = msg.quote_content
    prompt = msg.content
    
    # 检查是否引用的是图片
    if not (quote_content.endswith(".png") or quote_content.endswith(".jpg") or quote_content.endswith(".jpeg")):
        logger.error("引用消息不是图片名称")
        msg.quote("引用消息不是图片名称")
        return True
    
    # 检查文件是否存在
    file_path = os.path.join(SAVE_PATH, quote_content)
    if not os.path.exists(file_path):
        logger.error("图片不存在，请重新发送")
        msg.quote("图片不存在，请重新发送")
        return True
    
    # 处理图片
    logger.info("开始发送图片给n8n...")
    if context.is_group:
        logger.info(f"发送给Agent，完成后发送给：{context.chat_name}")
    
    new_file_path,output_message= send_n8n_file(context.sender, prompt, context.chat_info, context.webhook_url, file_path)
    logger.info("n8n返回的文件路径：" + new_file_path)
    if output_message:
        msg.quote(output_message)
    # 发送文件
    target = context.chat_name if context.is_group else context.sender
    wx.SendFiles(filepath=new_file_path, who=target, exact=False)
    logger.info(f"发送给 {target} 完成")
    
    return True

def handle_analzy_img_command(context: MessageContext) -> bool:
    """处理/analyimg命令"""
    msg=context.msg
    if not isinstance(msg, FriendQuoteMessage):
        msg.quote("analyimg 命令需要引用我发送的图片名称，请重新引用")
        return True
    
    quote_content = msg.quote_content
    prompt = msg.content
    
    # 检查是否引用的是图片
    if not (quote_content.endswith(".png") or quote_content.endswith(".jpg") or quote_content.endswith(".jpeg")):
        logger.error("引用消息不是图片名称")
        msg.quote("引用消息不是图片名称")
        return True
    
    # 检查文件是否存在
    file_path = os.path.join(SAVE_PATH, quote_content)
    if not os.path.exists(file_path):
        logger.error("图片不存在，请重新发送")
        msg.quote("图片不存在，请重新发送")
        return True
    
    # 处理图片
    logger.info("开始发送图片给n8n...")
    if context.is_group:
        logger.info(f"发送给Agent，完成后发送给：{context.chat_name}")
    
    _,output = send_n8n_file(context.sender, prompt, context.chat_info, context.webhook_url, file_path)
    logger.info("n8n返回的回复内容：" + output)
    #发送回复内容
    context.msg.quote(output)
    
    return True

def handle_clear_command(context: MessageContext) -> bool:
    """处理/clear命令"""
    response = send_n8n_aiagent(context.sender, "/clear", context.chat_info, context.webhook_url)
    logger.info("n8n返回的回复内容：" + str(response))
    result=response['data']
    output = result.get('output') or result.get('content', "No output")
    context.msg.quote(output)
    return True

def handle_help_command(context: MessageContext) -> bool:
    """处理/help命令"""
    help_text = """
可用命令：
/ps1 - 基于doubao-seededit-3-0-i2i 的图片处理命令（需要引用图片名称）
/ps2 - 基于gpt-image-1 的图片处理命令（需要引用图片名称）
/ps3 - 基于gemini-2.5-flash-image-preview 的图片处理命令（需要引用图片名称）
/genimg - 基于gpt-image-1 的图片生成命令（需要输入提示词）
/aimg - 基于gpt-4o 的图片分析命令（需要引用图片名称）
/clear - 清除上下文
/help - 显示帮助信息

使用方式：
- 私聊：直接发送消息或命令
- 群聊：@sylearn-bot 或使用命令（需要白名单权限）
    """
    time.sleep(1)
    context.msg.quote(help_text.strip())
    return True

def handle_genimg_command(context: MessageContext) -> bool:
    """处理/genimg命令"""
    prompt = context.msg.content
    logger.info(f"收到/genimg命令，开始处理")
    logger.info(f"正在发送给n8n...")
    response = send_n8n_aiagent(context.sender, prompt, context.chat_info, context.webhook_url)
    img_url=response['data']['img_url']
    img_type=response['data']['img_type']
    #下载图片
    img_path=download_file(img_url, os.path.join(SAVE_PATH, f"{context.sender}_{time.time()}.{img_type}"))
    #发送图片
    target = context.chat_name if context.is_group else context.sender
    wx.SendFiles(filepath=img_path, who=target, exact=False)
    logger.info(f"发送给 {target} 完成")
    return True

# 注册命令
CommandSystem.register_command("/ps1", handle_ps_command)
CommandSystem.register_command("/ps2", handle_ps_command)
CommandSystem.register_command("/ps3", handle_ps_command)
CommandSystem.register_command("/genimg", handle_genimg_command)
CommandSystem.register_command("/aimg", handle_analzy_img_command)
CommandSystem.register_command("/clear", handle_clear_command)
CommandSystem.register_command("/help", handle_help_command)


class ResponseManager:
    """响应管理器"""
    
    @staticmethod
    def send_ai_response(context: MessageContext, content: str):
        """发送AI响应"""
        response = send_n8n_aiagent(context.sender, content, context.chat_info, context.webhook_url)
        if response['status_code'] != 200:
            context.msg.quote("处理失败，请重试。(状态码："+str(response['status_code'])+")")
        else:
            result=response['data']
            response_content=result.get('output') or result.get('content', "No output")
            context.msg.quote(response_content)
    
    @staticmethod
    def handle_unknown_command(context: MessageContext):
        """处理未知命令"""
        context.msg.quote("不存在该命令")

# ========== 统一的消息处理逻辑 ==========

def process_message(context: MessageContext) -> bool:
    """统一的消息处理逻辑"""
    msg = context.msg
    
    if not isinstance(msg, FriendMessage):
        return False
    
    # 日志记录
    if context.is_group:
        logger.info(f"收到来自群聊 {context.chat_name} 消息")
        logger.info(f"发送者：{context.sender}")
    else:
        logger.info(f"Username:{context.sender}")
    
    # 1. 处理文件类型消息
    if MessageHandler.handle_file_message(context):
        return True
    
    ## 群聊消息处理
    if context.is_group and PermissionManager.should_respond_to_group_message(msg):
        logger.info(f"该消息@机器人，开始处理")
        #剔除前缀的@sylearn-bot
        msg.content= msg.content.replace("@sylearn-bot", "").strip()
        logger.info(f"消息内容：{msg.content}")
        # 检查是否是命令（需要白名单权限）
        if msg.content.startswith("/"):
            if not PermissionManager.can_use_commands(context.sender, context.is_group):
                logger.info(f"该消息无权限，静默处理")
                return True  # 无权限，静默处理
            # 执行命令
            command = CommandSystem.has_command(msg.content)
            if command:
                logger.info(f"该消息是命令消息，开始处理")
                return CommandSystem.execute_command(command, context)
            else:
                logger.info(f"该消息是命令消息，但不存在该命令，静默处理")
                ResponseManager.handle_unknown_command(context)
                return True
        else:
            if isinstance(msg, (FriendTextMessage, FriendVoiceMessage, FriendQuoteMessage)):
                # 记录消息内容
                logger.info(f"Message:{msg.content}")
                if isinstance(msg, FriendQuoteMessage):
                    logger.info(f"Quote:{msg.quote_content}")
                # 构建内容并发送AI响应
                content = MessageHandler.build_content(context)
                ResponseManager.send_ai_response(context, content)
                return True

    # 3. 处理私聊消息
    if not context.is_group:
        logger.info(f"该消息是私聊消息，开始处理")
        # 2. 处理命令
        if  msg.content.startswith("/"):
            logger.info(f"该消息是命令消息，开始处理")
            """处理私聊中的命令消息"""
            command = CommandSystem.has_command(msg.content)
            if command:
                return CommandSystem.execute_command(command, context)
            else:
                ResponseManager.handle_unknown_command(context)
                return True
        
        # 4. 处理普通消息（文本、语音、引用）
        if isinstance(msg, (FriendTextMessage, FriendVoiceMessage, FriendQuoteMessage)):
            logger.info(f"该消息是普通消息，开始处理")
            # 记录消息内容
            logger.info(f"Message:{msg.content}")
            if isinstance(msg, FriendQuoteMessage):
                logger.info(f"Quote:{msg.quote_content}")
            # 构建内容并发送AI响应
            content = MessageHandler.build_content(context)
            ResponseManager.send_ai_response(context, content)
            return True
        
    return False

# ========== 保持原有接口的简化函数 ==========
def process_friend_message(msg:FriendMessage, chat:str, webhook_url:str):
    """
        处理好友消息
        参数：
            msg(FriendMessage): 消息对象，必须为FriendMessage类型
            chat(str): 聊天对象
            webhook_url(str): webhook url
        返回：
            None
    """
    context = MessageContext(msg, chat, webhook_url, is_group=False)
    process_message(context)

def process_group_message(msg:FriendMessage, chat:str, webhook_url:str):
    """
        处理群聊消息
        参数：
            msg(FriendMessage): 消息对象，必须为FriendMessage类型
            chat(str): 聊天对象
            webhook_url(str): webhook url
        返回：
            None
    """
    context = MessageContext(msg, chat, webhook_url, is_group=True)
    process_message(context)

# ========== 回调函数 ==========

def on_friend_message(msg: FriendMessage, chat: str, webhook_url: str):
    """好友消息回调函数"""
    process_friend_message(msg, chat, webhook_url)

def on_group_message(msg: FriendMessage, chat: str, webhook_url: str):
    """群聊消息回调函数"""
    process_group_message(msg, chat, webhook_url)

# 设置日志
logging.basicConfig(level=LOG_LEVEL)
logger = logging.getLogger(__name__)

if __name__ == "__main__":
    logger.info("demo_wechat.py 应该通过 main.py 启动，而不是直接运行")