# 使用官方 Node LTS 镜像作为基础
FROM node:20

# 设置工作目录
WORKDIR /app

# 拷贝依赖文件并安装
COPY package.json package-lock.json ./
RUN npm install --production

# 拷贝构建产物
COPY build ./build

# 设置环境变量（可选）
ENV NODE_ENV=production
ENV PORT=3000

# 暴露应用端口（要和实际运行的端口匹配）
EXPOSE 3000

# 启动 SvelteKit Node 服务
CMD ["node", "build"]
