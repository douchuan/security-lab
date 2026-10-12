# SVG Illustration Skill

A project-level Claude Code Skill for generating and revising consistent, technically accurate SVG illustrations for a GitBook technical book.

## Install in a project

Extract this archive at the root of your book repository. The archive contains:

```text
.claude/
  skills/
    svg-illustration/
      SKILL.md
```

If you are extracting it elsewhere, copy the `svg-illustration` directory into your project's `.claude/skills/` directory.

## Use

Explicitly invoke the skill in Claude Code:

```md
/svg-illustration
主题：<填写插图主题>
目的：
<说明这张图要讲清楚什么概念或关系>
必需元素：
- <列出图中必须出现的角色、物体或节点>
- <...>
布局偏好：<从左到右 / 中心辐射 / 上下分层 等>
输出：完整 SVG，保存到教材的插图目录。
```

You can also describe the task in natural language. The skill's description helps Claude Code determine when it is relevant.

## Task fields

When useful, describe:
- Topic
- Purpose
- Required elements and relationships
- Layout preference
- Reference material (existing SVG/image/text)
- Requested changes
- Output path

These fields are optional guidance, not a mandatory form. Existing context in the conversation can be used.

## Design system

The skill preserves the source prompt's fixed white background, color palette, restrained flat-vector style, SVG constraints, treatment of existing source files, and validation checklist.
