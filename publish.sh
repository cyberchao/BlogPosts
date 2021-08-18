cd /Users/pangru/Documents/BlogPosts;git add .;git commit -m 'update';git push
ssh root@45.63.114.236 "cd /opt/blog/content/ ; git reset --hard ;git pull origin main;cd /opt/blog;hugo --buildFuture"
