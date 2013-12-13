用法
====

1  接收号码列表文件放在data目录中，扩展名为.txt，在脚本中指定文件名。

如文件为data/BJ.txt，在脚本中配置为：

    set fileName to "BJ"

号码列表文件内容格式为：
	+8613800000000
	
2  日志记录在log目录。

脚本执行前，需要确保log/all.log存在。

    touch log/all.log