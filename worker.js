export default {
  async fetch(request, env) {
    const { searchParams, pathname } = new URL(request.url);

    // 只处理根路径
    if (pathname === '/') {
      let botToken, chatId, text, parseMode;
      
      // 支持GET和POST请求
      if (request.method === 'POST') {
        // POST请求：从form data获取参数
        const formData = await request.formData();
        botToken = formData.get("token");
        chatId = formData.get("chat_id");
        text = formData.get("text");
        parseMode = formData.get("parse_mode") || formData.get("mode") || "HTML";
      } else {
        // GET请求：从URL参数获取
        botToken = searchParams.get("token");
        chatId = searchParams.get("chat_id");
        text = searchParams.get("text");
        parseMode = searchParams.get("parse_mode") || searchParams.get("mode") || "HTML";
      }

      // 校验必要参数
      if (!botToken || !chatId || !text) {
        const errorMsg = "Missing required parameters: token, chat_id, text";
        console.log(`[ERROR] ${errorMsg}`);
        return new Response(JSON.stringify({
          ok: false,
          error_code: 400,
          description: errorMsg
        }), { 
          status: 400,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          }
        });
      }

      try {
        // 对于GET请求需要URL解码，POST请求已经是解码的
        let decodedText = request.method === 'POST' ? text : decodeURIComponent(text);
        
        // 解码HTML实体和URL编码的换行符
        decodedText = decodedText
          .replace(/%0A/g, '\n')
          .replace(/%20/g, ' ')
          .replace(/%3A/g, ':')
          .replace(/%2F/g, '/');
        
        console.log(`[INFO] Proxying Telegram message to chat ${chatId}`);
        console.log(`[DEBUG] Text length: ${decodedText.length}`);
        console.log(`[DEBUG] Parse mode: ${parseMode}`);

        const apiUrl = `https://api.telegram.org/bot${botToken}/sendMessage`;
        const body = JSON.stringify({
          chat_id: chatId,
          text: decodedText,
          parse_mode: parseMode,
        });

        const response = await fetch(apiUrl, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
          },
          body,
        });

        const result = await response.text();
        
        // 记录响应状态
        console.log(`[INFO] Telegram API response status: ${response.status}`);
        if (!response.ok) {
          console.log(`[ERROR] Telegram API error: ${result}`);
        }

        // 返回响应，添加CORS头
        return new Response(result, { 
          status: response.status,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
            "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
            "Access-Control-Allow-Headers": "Content-Type"
          }
        });

      } catch (error) {
        const errorMsg = `Proxy error: ${error.message}`;
        console.log(`[ERROR] ${errorMsg}`);
        
        return new Response(JSON.stringify({
          ok: false,
          error_code: 500,
          description: errorMsg
        }), { 
          status: 500,
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          }
        });
      }
    }

    // 处理OPTIONS请求（CORS预检）
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 200,
        headers: {
          "Access-Control-Allow-Origin": "*",
          "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
          "Access-Control-Allow-Headers": "Content-Type"
        }
      });
    }

    // 其他路径返回404
    return new Response("Not Found", { 
      status: 404,
      headers: {
        "Content-Type": "text/plain",
        "Access-Control-Allow-Origin": "*"
      }
    });
  },
};
