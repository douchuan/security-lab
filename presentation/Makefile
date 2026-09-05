# Source markdown files
SRCS = README.md lesson-01.md lesson-02.md lesson-03.md lesson-04.md lesson-05.md lesson-06.md
HTMLS = $(SRCS:.md=.html)
PPTXS = $(SRCS:.md=.pptx)

# 重新生成所有格式
all: html pptx

html: $(HTMLS)

%.html: %.md
	marp $< --html --output $@

pptx: $(PPTXS)

%.pptx: %.md
	marp $< --pptx --output $@

# 打开 HTML 预览
open:
	open README.html

# 清理生成的文件
clean:
	rm -f *.html *.pptx

.PHONY: all html pptx open clean