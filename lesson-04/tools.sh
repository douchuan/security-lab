# 清理本实验 Docker 环境，释放磁盘空间
function clear() {
    # 查看当前 Docker 磁盘占用概况
    docker system df
    # 停止并移除所有容器、网络及卷（-v 会删除匿名卷，释放 Wazuh 索引数据）
    docker compose down -v
    # 清除 Docker BuildKit 构建缓存
    docker builder prune -a --force
}

"$@"