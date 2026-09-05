# 重新生成所有格式
all: html pptx

html: README.md
	marp $< --html --output Security-Lab.html

pptx: README.md
	marp $< --pptx --output Security-Lab.pptx

# 打开 HTML 预览
open:
	open Security-Lab.html

# 清理生成的文件
clean:
	rm -f Security-Lab.html Security-Lab.pptx

.PHONY: all html pptx open clean
