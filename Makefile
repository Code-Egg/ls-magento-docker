build_container:
	cd lsws-magento-dockerfiles/template; \
	./build.sh --lsws 5.4.6 --php lsphp73
	
say_hello:
	echo "Hello World"

prune:
	docker-compose kill
	sudo rm -rf data
	sudo rm -rf sites/localhost/html/*

reinstall:
	docker-compose kill
	docker-compose rm -f
	sudo rm -rf data
	sudo rm -rf sites/localhost/html/*
	docker-compose up -d
	sleep 6
	./bin/database.sh -D localhost
	./bin/appinstall.sh -A magento -S -D localhost
