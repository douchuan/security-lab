# 自定义规则

自定义 Decoder 不只是识别某种日志格式，它还可以把不同系统的原始日志，提取成 Wazuh 能用于规则判断的字段。

通常需要实现：

1. Decoder： 识别日志结构，提取字段
2. Rule： 根据提取的字段和具体语义，判断是否属于登录失败，并决定是否告警

Wazuh 的 Decoder 可以将日志中的内容提取为预定义字段或动态字段，Rule 再根据这些字段进行匹配。

## 统一日志语义

假设我们有三个系统，分别输出以下日志：

```
# Linux SSH
Failed password for admin from 192.168.1.10 port 51234 ssh2

# 某个应用
event=fail user=admin srcip=192.168.1.10

# 另一个应用
{"event":"password_failed","user":"admin","srcip":"192.168.1.10"}
```

它们的格式不同，但如果经过确认，三条日志确实都表示一次登录失败，我们希望最终得到类似的语义：

| 语义    | 示例值                    |
| ----- | ---------------------- |
| 事件类型  | authentication failure |
| 用户    | `admin`                |
| 来源 IP | `192.168.1.10`         |

注意：这张表表达的是我们希望建立的统一语义，并不是说 Wazuh 会自动将所有日志转成这个结构。

## 编写自定义 Decoder

假设这是一个教学用应用，它会把三种格式写入日志文件。为了让示例明确，我们统一给每条日志加上 `AUTH` 前缀：

```
AUTH Failed password for admin from 192.168.1.10
AUTH fail user=admin srcip=192.168.1.10
AUTH password_failed user=admin srcip=192.168.1.10
```

在 Wazuh Manager 上，可以把自定义 Decoder 放入：

`/var/ossec/etc/decoders/local_decoder.xml`

示例：

```xml
<decoder name="auth-event">
  <prematch>^AUTH </prematch>
</decoder>

<decoder name="auth-failed-password">
  <parent>auth-event</parent>
  <regex>^AUTH Failed password for (\w+) from (\d+\.\d+\.\d+\.\d+)</regex>
  <order>user,srcip</order>
</decoder>

<decoder name="auth-fail">
  <parent>auth-event</parent>
  <regex>^AUTH fail user=(\w+) srcip=(\d+\.\d+\.\d+\.\d+)</regex>
  <order>user,srcip</order>
</decoder>

<decoder name="auth-password-failed">
  <parent>auth-event</parent>
  <regex>^AUTH password_failed user=(\w+) srcip=(\d+\.\d+\.\d+\.\d+)</regex>
  <order>user,srcip</order>
</decoder>
```

这里有几个关键点：

- `prematch`：先判断日志是否属于 `AUTH` 这一类。
- `parent`：将三个子 Decoder 组织在共同的父 Decoder 之下。
- `regex`：从日志中提取需要的内容。括号里的捕获组用于提取字段。
- `order`：把第一个捕获组映射到 `user`，第二个映射到 `srcip`。

这些写法利用了 Wazuh 的父子 Decoder 和字段提取机制。

三个子 Decoder 的输出都能提取出相同的 `user` 和 `srcip` 字段。但到这里，我们还没有真正告诉 Wazuh：这是一条登录失败事件。

## 让 Wazuh 理解“登录失败”的语义

这一步通过 Rule 完成。

在 `/var/ossec/etc/rules/local_rules.xml` 中添加规则：

```xml
<group name="local,authentication,">

  <rule id="100100" level="5">
    <decoded_as>auth-failed-password</decoded_as>
    <description>Authentication failed: Failed password</description>
    <group>authentication_failed,</group>
  </rule>

  <rule id="100101" level="5">
    <decoded_as>auth-fail</decoded_as>
    <description>Authentication failed: fail</description>
    <group>authentication_failed,</group>
  </rule>

  <rule id="100102" level="5">
    <decoded_as>auth-password-failed</decoded_as>
    <description>Authentication failed: password_failed</description>
    <group>authentication_failed,</group>
  </rule>

</group>
```

这里使用了三个自定义规则 ID。Wazuh 官方建议自定义规则使用 `100000–120000` 范围内的 ID，以降低与内置规则冲突的风险。

注意规则中的两个重要概念：

- `<decoded_as>`：要求日志匹配指定的 Decoder
- `<group>authentication_failed,</group>`：给规则命中的事件打上一个共同的分类标签

当三条日志分别命中对应规则时，它们都会被归入 `authentication_failed` 这一组。

### 自定义字段和 Wazuh 语义究竟如何关联？

可以把它理解为三个层次：

第一层：原始表达

`Failed password` · `fail` · `password_failed`

第二层：Decoder 解析

识别日志格式，提取 `user`、`srcip` 等字段。

第三层：Rule 赋予安全分类

匹配对应的 Decoder，并将事件归类到 `authentication_failed`。

这里需要区分两类名称：

| 名称                                 | 含义                     |
| ---------------------------------- | ---------------------- |
| `user`、`srcip`                     | Wazuh 支持的预定义字段，具有约定的用途 |
| `auth-fail`、`auth-password-failed` | 我们自己命名的 Decoder        |
| `authentication_failed`            | 我们通过规则定义的事件分类标签        |

`authentication_failed` 并不是因为名字被写出来，就自动获得特殊含义。 是我们编写的规则将对应日志归入了这个分类。后续还可以利用该组进行规则关联，例如统计同一来源 IP 在一段时间内出现的多次失败事件。

## 4. 如果第三方应用使用不同的字段名呢？

例如，某个应用输出 JSON：

```
{
  "event": "password_failed",
  "username": "admin",
  "client_ip": "192.168.1.10"
}
```

另一个应用可能输出：

```
{
  "action": "fail",
  "user": "admin",
  "source": "192.168.1.10"
}
```

如果日志本身是有效 JSON，Wazuh 的 JSON Decoder 通常可以解析这些字段。你可以直接针对 `event`、`action` 等字段编写规则，也可以在需要时自定义解析逻辑。Wazuh 支持动态字段，因此不必把每一个应用的字段名都强行映射为预定义字段。

实际设计时，可以选择两种方法：

- 直接按各应用的字段写规则： 更贴近原始日志，适合简单场景
- 建立统一的事件分类： 为不同来源编写对应的 Decoder 和 Rule，让它们归入共同的 `authentication_failed` 分类，更适合后续关联分析

后一种方式的价值在于：当系统接入越来越多的日志来源时，不必让每条检测规则都重复理解所有应用的表达方式。

## 如何验证这个例子？

在 Wazuh Manager 上，可以使用官方提供的 `wazuh-logtest` 测试原始日志是否匹配预期的 Decoder 和 Rule：

```
/var/ossec/bin/wazuh-logtest
```

然后逐条输入前面三条示例日志，检查：

1. 是否命中了预期的 Decoder
2. `user` 和 `srcip` 是否被正确提取
3. 是否命中了对应的自定义规则
4. 规则组中是否出现 `authentication_failed`

配置文件的路径、语法和匹配结果都应以实际测试为准；示例中的 `AUTH` 前缀是为了教学而人为添加的，并不是 SSH 的真实日志格式。

最后还有一个很重要的区别：对于标准 Linux SSH 日志，Wazuh 已经提供了相关内置 Decoder 和规则。因此，实际部署时不应为了识别 `Failed password` 就直接添加重复的自定义规则。可以先用 `wazuh-logtest` 检查现有规则是否已经能处理它，再决定是否需要扩展。