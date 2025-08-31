import requests
import json
from typing import Dict, Any, Optional, Union
import hashlib
import os
import logging
import time
from config import REQUEST_TIMEOUT, IMG_DOWNLOAD_TIMEOUT, AUTH_HEADER_KEY, AUTH_HEADER_VALUE, ERROR_IMG_PATH

# 设置日志
logger = logging.getLogger(__name__)

class WebhookTrigger:
    """webhook触发器，带有响应处理功能。"""
    
    def __init__(self, webhook_url: str):
        # 初始化webhook_url
        self.webhook_url = webhook_url 
        # 初始化requests会话
        self.session = requests.Session()
        
        # 设置基础请求头（可选）
        self.session.headers.update({
            'User-Agent': 'WebhookTrigger/1.0' # 用户代理，这里的内容可以自定义
        })

    # 触发webhook
    def trigger(self, method: str = 'POST', body: Optional[Union[Dict, str, bytes]] = None, 
                content_type: Optional[str] = None, timeout: int = REQUEST_TIMEOUT,files:Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        """ 
        触发webhook并返回结构化响应。
        
        参数:
            method: HTTP方法 ('GET', 'POST', 'PUT', 'PATCH', 'DELETE')
            body: 请求体数据 (字典、字符串或字节)
            content_type: 内容类型
            timeout: 请求超时时间（秒）
            files: 文件
        返回:
            包含响应数据和元数据的字典
        """
        try:
            # 准备请求参数
            kwargs = {'timeout': timeout}
            # 设置请求头信息
            headers = {AUTH_HEADER_KEY: AUTH_HEADER_VALUE} # 头认证信息
            
            # 处理文件上传和数据
            if files is not None:
                # 文件上传模式：使用data而不是json，让requests自动设置Content-Type为multipart/form-data
                kwargs['files'] = files
                if body is not None and isinstance(body, dict):
                    kwargs['data'] = body  # 使用data而不是json
                # 不设置Content-Type，让requests自动处理
            elif body is not None:
                # 普通数据模式
                if isinstance(body, dict):
                    kwargs['json'] = body
                    headers['Content-Type'] = 'application/json'
                elif isinstance(body, str):
                    kwargs['data'] = body
                    headers['Content-Type'] = content_type or 'text/plain'
                elif isinstance(body, bytes):
                    kwargs['data'] = body
                    headers['Content-Type'] = content_type or 'application/octet-stream'
            # 如果方法为POST、PUT、PATCH，则设置默认Content-Type
            elif method.upper() in ['POST', 'PUT', 'PATCH']:
                headers['Content-Type'] = content_type or 'application/json'
            
            # 更新会话头
            if headers:
                self.session.headers.update(headers)
            
            
            # 发送请求
            response = self.session.request(method.upper(), self.webhook_url, **kwargs)

            # 如果请求失败，则抛出异常
            response.raise_for_status()
            
            # 尝试解析JSON响应
            try:
                response_data = response.json()
            # 如果解析失败，则返回响应内容
            except json.JSONDecodeError:
                response_data = response.text
            
            return {
                'status_code': response.status_code, # 状态码
                'data': response_data # 响应数据，这里返回的是json格式
            }
            
        except requests.exceptions.RequestException as e:
            return {
                'success': False,
                'error': str(e)
            }
        finally:
            # 清理临时头
            if headers:
                for key in headers:
                    self.session.headers.pop(key, None)


def send_n8n_aiagent(send_user,send_message,chat_info,webhook_url)->str:
    """
        发送消息给n8n，并返回n8n的回复
        参数：
            send_user(str): 发送者
            send_message(str): 发送消息
            chat_info(json): 聊天信息识别
            webhook_url(str): webhook url
        返回：
            str: 回复消息
    """
    if webhook_url is None:
        return "webhook_url is None"
    trigger = WebhookTrigger(webhook_url)
    #基于chat_info生成唯一id
    chat_id = hashlib.sha256(str(chat_info).encode()).hexdigest()
    result = trigger.trigger(method='POST', body={"message":send_message,"chat_id":chat_id,"send_user":send_user})
    return result

def send_n8n_file(send_user,send_message,chat_info,webhook_url,file_path,timeout=REQUEST_TIMEOUT)->str:
    """
        发送文件给n8n，并返回n8n的回复
        参数：
            send_user(str): 发送者
            send_message(str): 发送消息
            chat_info(json): 聊天信息识别
            webhook_url(str): webhook url
            file_path(str): 文件本地路径
            timeout(int): 请求超时时间（秒），从配置文件读取
        返回：
            str: 文件路径
            str: 回复消息
    """
    if webhook_url is None:
        return "webhook_url is None",""
    
    # 检查文件是否存在
    if not os.path.exists(file_path):
        return f"文件不存在: {file_path}",""
    
    trigger = WebhookTrigger(webhook_url)
    #基于chat_info生成唯一id
    chat_id = hashlib.sha256(str(chat_info).encode()).hexdigest()
    output_message = ""
    download_file_path = "No file_path"
    try:
        # 读取文件内容到内存中，避免文件句柄在请求时关闭
        with open(file_path, 'rb') as f:
            file_content = f.read()
        
        # 准备文件数据
        files = {'file': (os.path.basename(file_path), file_content, 'image/*')}
        #发送请求
        response = trigger.trigger(
            method='POST', 
            body={
                "message": send_message,
                "chat_id": chat_id,
                "send_user": send_user,
                "img_name": os.path.basename(file_path)
            },
            files=files,
            timeout=timeout
        )
        if response['status_code'] != 200:
            return ERROR_IMG_PATH,"处理失败，请重试。(状态码："+str(response['status_code'])+")"
        #回复包含图片的url和回复内容
        #处理响应
        result=response['data']
        logger.info(f"n8n返回的响应: {result}")
        # 处理响应
        # 如果包含img_url，则下载图片
        if 'file_url' in result:
            file_url = result['file_url']
            file_type = result['file_type']
            save_url_path = os.path.dirname(file_path)
            file_name, file_ext = os.path.splitext(os.path.basename(file_path))
            # 生成时间戳
            timestamp = int(time.time())
            # 构造新文件名：原文件名_ps_时间戳.扩展名
            save_url_name = f"{file_name}_{timestamp}.{file_type}"
            download_file_path = download_file(file_url, os.path.join(save_url_path, save_url_name))
        
        # 处理回复内容(字段是：output或content，get取值，第二个参数是默认值)
        output_message = result.get('output',"") or result.get('content',"")
        return download_file_path,output_message
            
    except Exception as e:
        logger.error(f"发送文件给n8n失败: {str(e)}")
        return ERROR_IMG_PATH,"处理失败，请重试。"

def download_file(file_url,save_path):
    """
        下载图片到指定目录，并返回文件路径
        参数：
            file_url(str): 文件url
            save_path(str): 保存路径
        返回：
            str: 文件路径
    """
    try:
        #print("下载图片到指定目录，并返回文件路径："+save_path)
        response = requests.get(file_url, timeout=IMG_DOWNLOAD_TIMEOUT)
        response.raise_for_status()  # 检查HTTP状态码
        
        # 确保目录存在
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        
        # 保存文件
        with open(save_path, 'wb') as f:
            # 使用iter_content确保完整下载
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
        
        # 验证文件是否成功保存
        if os.path.exists(save_path) and os.path.getsize(save_path) > 0:
            return save_path
        else:
            raise Exception("文件下载失败或文件为空")
            
    except requests.exceptions.RequestException as e:
        raise Exception(f"下载文件失败: {str(e)}")
    except Exception as e:
        raise Exception(f"保存文件失败: {str(e)}")

if __name__ == "__main__":
    from config import WEBHOOK_TEST_URL
    send_user = "测试用户"
    send_message = "你是谁？"
    chat_info = "测试"
    result = send_n8n_aiagent(send_user, send_message, chat_info, WEBHOOK_TEST_URL)
    print(result)
        
