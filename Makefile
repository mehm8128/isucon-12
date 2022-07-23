WEBHOOK_URL=https://discord.com/api/webhooks/993867060528549928/79xOfLjqv1PHuwyP6JCZeO2ShK4pHdL9qJSCOh7v5xd5bZIwhu-g4tWVR9MpP-7oE_0k

.PHONY: build
build:
	sudo systemctl daemon-reload; \
	sudo systemctl restart isuports.service;

.PHONY: alp
alp:
	sudo cat /var/log/nginx/access.log | alp ltsv -m '/api/organizer/player/[0-9a-z-]+/disqualified,/api/organizer/competition/[0-9a-z-]+/finish,/api/organizer/competition/[0-9a-z-]+/score,/api/player/player/[0-9a-z-]+,/api/player/competition/[0-9a-z-]+/ranking' --sort avg -r > alp_log.txt
	sudo mv alp_log.txt /temp/alp_log.txt
	curl -X POST -F alp_log=@/temp/alp_log.txt ${WEBHOOK_URL}

.PHONY: slow-show
slow-show:
	sudo pt-query-digest /var/log/mysql/mysql-slow.log > pt-query-digest_log.txt
	sudo mv pt-query-digest_log.txt /temp/pt-query-digest_log.txt
	curl -X POST -F pt-query-digest_log=@/temp/pt-query-digest_log.txt ${WEBHOOK_URL}

.PHONY: pprof
pprof:
	go tool pprof -http=0.0.0.0:8080 /home/isucon/webapp/go/isuports http://localhost:6060/debug/pprof/profile
.PHONY: pprof-image
pprof-image:
	go tool pprof -png -output pprof.png http://localhost:6060/debug/pprof/profile
	sudo mv pprof.png /temp/pprof.png
	curl -X POST -F pprof=@/temp/pprof.png ${WEBHOOK_URL}

.PHONY: truncate
truncate:
	sudo truncate -s 0 -c /var/log/nginx/access.log
	sudo truncate -s 0 -c /var/log/mysql/mysql-slow.log

.PHONY: restart-mysql
restart-mysql:
	sudo cp ./mysqld.cnf /etc/mysql/mysql.conf.d/mysqld.cnf
	sudo systemctl restart mysql
.PHONY: restart-nginx
restart-nginx:
	sudo cp ./nginx.conf /etc/nginx/nginx.conf
	sudo systemctl restart nginx

.PHONY: setting-mysql
setting-mysql:
	sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
.PHONY: setting-nginx
setting-nginx:
	sudo nano /etc/nginx/nginx.conf

.PHONY: pre-bench
pre-bench:
	make restart-mysql
	make restart-nginx
	make build
	make truncate
.PHONY: after-bench
after-bench:
	make alp
	make slow-show

.PHONY: setup
setup:
	wget https://github.com/tkuchiki/alp/releases/download/v1.0.9/alp_linux_amd64.zip
	unzip alp_linux_amd64.zip
	sudo install ./alp /usr/local/bin
	sudo apt -y install percona-toolkit
	wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh
	sudo mkdir /temp
	sudo apt -y install graphviz
	cp /etc/nginx/nginx.conf ~/webapp
	cp /etc/mysql/mysql.conf.d/mysqld.cnf ~/webapp

.PHONY: pprof-record
pprof-record:
	go tool pprof http://localhost:6060/debug/pprof/profile
.PHONY: pprof-check
pprof-check:
	$(eval latest := $(shell ls -rt ~/pprof/ | tail -n 1))
	go tool pprof -http=localhost:8090 ~/pprof/$(latest)