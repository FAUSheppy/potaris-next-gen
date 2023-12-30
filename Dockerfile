FROM alpine

RUN apk add git
RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community hugo

RUN hugo new site hugo-site
WORKDIR /hugo-site

RUN git clone https://github.com/hugo-sid/hugo-blog-awesome.git themes/hugo-blog-awesome
RUN mkdir /hugo-site/themes/hugo-blog-awesome/site/
COPY site/ /hugo-site/themes/hugo-blog-awesome/site/
RUN ls -ll /hugo-site/themes/hugo-blog-awesome/site/
WORKDIR /hugo-site/themes/hugo-blog-awesome/site

ENTRYPOINT ["hugo"]
CMD ["server", "--themesDir", "../..", "--bind", "0.0.0.0", "--port", "5000"]
