#!/bin/bash
auth_email=""                                     # 用于登录https://dash.cloudflare.com的邮箱
auth_method="global"                                            # Api Key类型"global"或"token"其中一种
auth_key=""            # Api Key
zone_identifier=""             # 域名概览页（Overview）找到区域id（Zone ID）
record_name="sub.heheda.io"                                 # 需要更新的域名A记录+根域名全称，比如要更新domain.com的sub子域名，就完整填入，即record_name="sub.domain.com"
ttl="60"                                                       # DNS TTL (单位秒，最低60)
proxy=false                                                    # 是否通过Cloudflare代理
tgChatId="123123"                                           # tgChatId
tgBotToken="123123:eynfisgbbkvfangc"    # tgBotToken
tgurl=""                 # tgurl，不需要tg推送更新情况的话，此处留空即可，需要则填"https://api.telegram.org/bot${tgBotToken}/sendMessage"
###########################################
## 推送
###########################################
sendnotify() {
    if [[ $tgurl != "" ]]; then
        notify=$(curl -s -X POST $tgurl -d chat_id=${tgChatId} -d text="${message}")
        case "$notify" in
        *"\"success\":false"*)
            printf "Telegram推送失败。\n"
            exit 1
            ;;
        *)
            printf "Telegram推送成功。\n"
            exit 0
            ;;
        esac
    fi
    printf "未开启Telegram推送功能。\n"
}
###########################################
## 检测公网IP（如果你的环境有做科学上网，请注意选择下面适合自己的ip获取域名）
###########################################
ip=$(curl -s https://api.ipify.org || curl -s https://ipv4.icanhazip.com/ || curl -s http://members.3322.org/dyndns/getip)
if [ "${ip}" == "" ]; then
    printf "DDNS 更新助手：公网IP获取失败\n"
    message="DDNS 更新助手：公网IP获取失败"
    sendnotify
    exit 1
fi
###########################################
## 检查api_key类型
###########################################
if [ "${auth_method}" == "global" ]; then
    auth_header="X-Auth-Key:"
else
    auth_header="Authorization: Bearer"
fi
###########################################
## 查找A记录是否存在
###########################################
printf "DDNS 更新助手： 检查开始...\n"
record=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records?type=A&name=$record_name" \
    -H "X-Auth-Email: $auth_email" \
    -H "$auth_header $auth_key" \
    -H "Content-Type: application/json")
if [[ $record == *"\"count\":0"* ]]; then
    printf "DDNS 更新助手：${record_name} 记录不存在，请先手动创建一次 ${record_name} 记录\n"
    message="DDNS 更新助手：${record_name} 记录不存在，请先手动创建一次 ${record_name} 记录"
    sendnotify
    exit 1
fi
###########################################
## 获取已存在的IP
###########################################
old_ip=$(echo "$record" | sed -E 's/.*"content":"(([0-9]{1,3}\.){3}[0-9]{1,3})".*/\1/')
# Compare if they're the same
if [[ $ip == $old_ip ]]; then
    printf "DDNS 更新助手： ${record_name} 记录IP - ${ip}未发生变动\n"
##如果自己设置的定时比较频繁，比如10分钟或者半小时更新一次，建议删除下面两行
##删除起点
    message="DDNS 更新助手： ${record_name} 记录IP - ${ip}未发生变动"
    sendnotify
##删除终点
    exit 0
fi
###########################################
## 匹配record id
###########################################
record_identifier=$(echo "$record" | sed -E 's/.*"id":"(\w+)".*/\1/')
###########################################
## 更新IP
###########################################
update=$(curl -s -X PATCH "https://api.cloudflare.com/client/v4/zones/$zone_identifier/dns_records/$record_identifier" \
    -H "X-Auth-Email: $auth_email" \
    -H "$auth_header $auth_key" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$record_name\",\"content\":\"$ip\",\"ttl\":\"$ttl\",\"proxied\":${proxy}}")
###########################################
## 最终状态反馈
###########################################
case "$update" in
*"\"success\":false"*)
    printf "DDNS 更新助手：DDNS记录$record_name更新失败，详细信息：\n$update\n"
    message="DDNS 更新助手：DDNS记录$record_name更新失败，请手动查看日志。"
    sendnotify
    exit 1
    ;;
*)
    printf "DDNS 更新助手： DDNS 已更新，$record_name - $ip。\n"
    message="DDNS 更新助手：DDNS记录更新成功，当前$record_name的新IP地址为：$ip。"
    sendnotify
    exit 0
    ;;
esac
