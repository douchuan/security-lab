#!/usr/bin/env bash

set -euo pipefail

WORKDIR="./outputs"

init_case() {
    mkdir -p "$WORKDIR"
    cd "$WORKDIR"

    if [[ ! -f message.txt ]]; then
        echo "This is a confidential message." > message.txt
    fi
}

# 1. 随机数
rand_case() {
    echo "=== 1. Random Number ==="

    echo "[1] Generate 16 random bytes (hex):"
    openssl rand -hex 16

    echo
    echo "[2] Generate 32 random bytes (binary):"
    openssl rand -out random.bin 32
    xxd random.bin
}

# 2. 对称加密：AES-256-CBC
#
# 常见分组密码模式（Mode of Operation）：
#   - ECB（Electronic Codebook）：最简单，相同明文块产生相同密文块，不推荐使用。
#   - CBC（Cipher Block Chaining）：每个明文块先与前一个密文块异或再加密，需 IV；
#     适用于静态数据加密，但不适合流式数据（需填充、不能并行加密）。
#   - CTR（Counter）：将计数器加密后与明文异或，无需填充，可并行加解密，常用于高性能场景。
#   - GCM（Galois/Counter Mode）：CTR 模式 + GMAC 认证，提供机密性和完整性（AEAD），
#     推荐用于网络通信（TLS 1.3 默认使用 AES-GCM）。
#   - CFB（Cipher Feedback）/ OFB（Output Feedback）：将分组密码转为流密码，
#     适合逐字节传输的场景（如串口通信）。
#
# 本实验演示 CBC 模式。
symmetric_case() {
    echo "=== 2. Symmetric Encryption (AES-256-CBC) ==="

    local key iv

    key=$(openssl rand -hex 32)
    iv=$(openssl rand -hex 16)

    echo "This is a symmetric encryption demo." > plaintext.txt

    openssl enc -aes-256-cbc \
        -e -in plaintext.txt -out encrypted.bin \
        -K "$key" -iv "$iv"

    openssl enc -aes-256-cbc \
        -d -in encrypted.bin -out decrypted.txt \
        -K "$key" -iv "$iv"

    echo "Ciphertext:"
    xxd encrypted.bin

    echo
    echo "Decrypted text:"
    cat decrypted.txt

    # 保存参数仅用于本地教学实验
    printf '%s\n' "$key" > aes-key.txt
    printf '%s\n' "$iv" > aes-iv.txt
}

# 3. 公钥密码：RSA-OAEP
#
# 为什么要填充（Padding）？
#   原始 RSA（教科书 RSA）是"裸"的模幂运算，直接使用有严重安全问题：
#   - 确定性：相同明文每次都产生相同密文，攻击者可通过观察密文判断
#     两次加密是否为同一内容（投票、拍卖等场景会泄露信息）。
#   - 同态性质：E(m1) × E(m2) = E(m1 × m2)，攻击者可以在密文上做代数
#     运算来推导明文。
#   - 短明文攻击：明文远小于密钥长度时，攻击者可枚举所有可能明文，
#     逐个加密后与目标密文比对。
#   OAEP（Optimal Asymmetric Encryption Padding）在加密前将明文与
#   随机数混合，使每次加密结果不同，破坏上述攻击路径。
#
# 除了 RSA，还可以使用 ECC（椭圆曲线密码学）：
#   - RSA：基于大整数分解难题，2048 位密钥安全性约等于 112 位对称密钥，
#     密钥较长，但兼容性最好。
#   - ECC（ECDH / ECDSA）：基于椭圆曲线离散对数难题，256 位密钥安全性
#     约等于 128 位对称密钥，密钥更短、计算更快，适合资源受限环境
#     和现代协议（TLS 1.3 默认优先使用 ECC）。
#   本实验使用 RSA-OAEP 做加密演示；ECC 加密在实际中通常通过
#   ECDH 密钥协商 + 对称加密（Hybrid Encryption）实现。
public_key_case() {
    echo "=== 3. Public-Key Cryptography (RSA-OAEP) ==="

    openssl genpkey \
        -algorithm RSA \
        -pkeyopt rsa_keygen_bits:2048 \
        -out private.pem

    openssl pkey \
        -in private.pem \
        -pubout \
        -out public.pem

    echo -n "Secret key exchange demo" > small.txt

    openssl pkeyutl \
        -encrypt \
        -pubin -inkey public.pem \
        -in small.txt \
        -out rsa-encrypted.bin \
        -pkeyopt rsa_padding_mode:oaep \
        -pkeyopt rsa_oaep_md:sha256

    openssl pkeyutl \
        -decrypt \
        -inkey private.pem \
        -in rsa-encrypted.bin \
        -out rsa-decrypted.txt \
        -pkeyopt rsa_padding_mode:oaep \
        -pkeyopt rsa_oaep_md:sha256

    echo "Decrypted text:"
    cat rsa-decrypted.txt
    echo
    echo "Public key: public.pem"
    echo "Private key: private.pem"
}

# 4. 散列函数：SHA-256
hash_case() {
    echo "=== 4. Hash Function (SHA-256) ==="

    echo "Original content:" > hash-message.txt
    echo "Original content:" >> hash-message.txt

    echo "[1] Original hash:"
    openssl dgst -sha256 hash-message.txt

    echo "Modified content:" > hash-message.txt

    echo
    echo "[2] Hash after modification:"
    openssl dgst -sha256 hash-message.txt
}

# 5. 消息认证码：HMAC-SHA-256
#
# HMAC 的适用场景：
#   HMAC（Hash-based Message Authentication Code）使用共享密钥和哈希
#   函数，同时提供**完整性**（消息未被篡改）和**认证性**（消息来自持有
#   密钥的一方）。
#   - API 请求签名：服务端验证请求确实来自持有 API Key 的客户端，
#     防止请求被中间人篡改（如 AWS Signature V4、微信支付 API）。
#   - 会话令牌完整性：服务端只保存 HMAC 密钥，发给客户端的 token
#     附带 HMAC 签名，客户端回传时服务端验签即可，无需查数据库
#     （如 JWT 的 HS256 算法本质就是 HMAC）。
#   - 消息队列 / 微服务间通信：验证消息确实来自内部服务而非外部注入。
#   - 文件下载校验：服务端用密钥对文件生成 HMAC，客户端下载后用
#     同一密钥验签，既校验完整性又确认来源可信（比裸 SHA-256 多一层
#     来源认证）。
#
# 与裸哈希（hash_case）的区别：
#   裸哈希只能检测"内容是否被改变"，无法确认"改变者是谁"（任何人都能
#   重新算一次哈希）。HMAC 引入了密钥，只有持有密钥的人才能生成正确的
#   MAC 值，因此同时提供完整性和来源认证。
#
# 与数字签名（signature_case）的区别：
#   HMAC 是共享密钥，双方都能生成和验证 MAC，无法向第三方证明消息
#   来源（不可抵赖）。数字签名使用非对称密钥，私钥签名、公钥验签，
#   具有不可抵赖性，但性能更低。
mac_case() {
    echo "=== 5. Message Authentication Code (HMAC-SHA-256) ==="

    local secret="demo-shared-secret"

    echo "Transfer \$100 to Alice." > mac-message.txt

    echo "[1] HMAC of original message:"
    openssl dgst -sha256 -hmac "$secret" mac-message.txt

    echo "Transfer \$900 to Alice." > mac-message.txt

    echo
    echo "[2] HMAC after modification:"
    openssl dgst -sha256 -hmac "$secret" mac-message.txt
}

# 6. 数字签名：RSA + SHA-256
signature_case() {
    echo "=== 6. Digital Signature (RSA + SHA-256) ==="

    # 若前面尚未生成密钥，则在此生成
    if [[ ! -f private.pem || ! -f public.pem ]]; then
        openssl genpkey \
            -algorithm RSA \
            -pkeyopt rsa_keygen_bits:2048 \
            -out private.pem

        openssl pkey \
            -in private.pem \
            -pubout \
            -out public.pem
    fi

    echo "This is a message to sign." > signed-message.txt

    openssl dgst -sha256 \
        -sign private.pem \
        -out signature.bin \
        signed-message.txt

    echo "[1] Verify original message:"
    openssl dgst -sha256 \
        -verify public.pem \
        -signature signature.bin \
        signed-message.txt

    echo "Tampered content." > signed-message.txt

    echo
    echo "[2] Verify modified message (expected to fail):"
    if openssl dgst -sha256 \
        -verify public.pem \
        -signature signature.bin \
        signed-message.txt; then
        echo "Unexpected: verification succeeded."
    else
        echo "Expected result: verification failed."
    fi
}

show_menu() {
    cat <<'EOF'

OpenSSL Cryptography Demo
-------------------------
1. Random Number
2. Symmetric Encryption
3. Public-Key Cryptography
4. Hash Function
5. Message Authentication Code (HMAC)
6. Digital Signature
7. Run All
0. Exit
EOF
}

main() {
    init_case

    while true; do
        show_menu
        read -r -p "Choose an option: " choice

        case "$choice" in
            1) rand_case ;;
            2) symmetric_case ;;
            3) public_key_case ;;
            4) hash_case ;;
            5) mac_case ;;
            6) signature_case ;;
            7)
                rand_case
                symmetric_case
                public_key_case
                hash_case
                mac_case
                signature_case
                ;;
            0)
                echo "Goodbye."
                break
                ;;
            *)
                echo "Invalid option."
                ;;
        esac

        echo
    done
}

main