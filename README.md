# octra-wallet-gen  适合VPS部署钱包并使用本地web端生成新钱包。启动后会引导输入IP 和ssh端口信息并自动启动服务。本地端win系统cmd输入提示信息登陆vps后 即可用浏览器打开钱包生成页面，完成后记得运行脚本选项2删除选项，他会删掉钱包目录数据并关闭临时开启的隧道端口 
curl -fsSL https://raw.githubusercontent.com/acxcr/octra-wallet-gen/main/wallet-gen.sh -o wallet-gen.sh && chmod +x wallet-gen.sh && ./wallet-gen.sh
