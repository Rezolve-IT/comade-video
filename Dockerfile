FROM nginx:alpine
RUN rm -f /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html hls.min.js comade.png /usr/share/nginx/html/
