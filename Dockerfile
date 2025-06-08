# 使用一个轻量级的 Linux 发行版作为基���镜像
FROM ubuntu:latest

# 设置工作目录
WORKDIR /app

# 将编译好的可执行文件复制到镜像中
# 假设 flow_stress_test 已经存在于 target/release/ 目录下
COPY target/release/flow_stress_test .

# 将 assets 文件夹复制到镜像中
COPY assets ./assets

# 赋予可执行文件执行权限
RUN chmod +x flow_stress_test

# 设置 ENTRYPOINT，这样在运行容器时，任何附加的命令行参数都会传递给 flow_stress_test
ENTRYPOINT ["./flow_stress_test"]

# 可以在这里提供一个默认的 CMD，如果 ENTRYPOINT 没有被覆盖的话
CMD ["--help"]