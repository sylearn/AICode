# 链接N8N的微信机器人

    ```mermaid
    graph TD
    A["收到消息"] --> B["MessageContext"]
    B --> C["process_message()"]
    
    C --> D{文件消息?}
    D -->|是| E["MessageHandler.handle_file_message()"]
    E --> F["保存文件并回复"]
    
    D -->|否| G{群聊权限检查}
    G -->|无权限| H["静默处理"]
    G -->|有权限| I{是命令?}
    
    I -->|是| J["CommandSystem.has_command()"]
    J -->|找到| K["CommandSystem.execute_command()"]
    J -->|未找到| L["ResponseManager.handle_unknown_command()"]
    
    I -->|否| M["MessageHandler.build_content()"]
    M --> N["ResponseManager.send_ai_response()"]
    
    K --> O{"/ps命令?"}
    K --> P{"/help命令?"}
    K --> Q["其他命令..."]
    
    O --> R["handle_ps_command()"]
    P --> S["handle_help_command()"]
    
    style A fill:#e1f5fe
    style C fill:#f3e5f5
    style J fill:#e8f5e8
    style R fill:#fff3e0
    style S fill:#fff3e0

    ```