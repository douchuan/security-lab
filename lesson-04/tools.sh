function clear() {
    docker system df
    docker compose down -v
    docker builder prune -a 
}

"$@"