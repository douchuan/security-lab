# Source markdown files
SRCS = README.md lesson-01.md lesson-02.md lesson-03.md lesson-04.md lesson-05.md lesson-06.md SETUP.md
PDFS = $(SRCS:.md=.pdf)

# 生成全部 PDF
all: pdf

pdf: $(PDFS)

%.pdf: %.md
	marp $< --pdf --output $@

# 打开 PDF 预览
open:
	open README.pdf

# 清理生成的文件
clean:
	rm -f *.pdf

.PHONY: all pdf open clean