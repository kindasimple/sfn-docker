

up:
	docker compose up -d

down:
	docker compose down

start: up build
	./setup_aws_batch.sh

logs:
	docker compose logs -f

open:
	open http://localhost:5555/moto-api

reset:
	curl -XPOST http://localhost:5555/moto-api/reset

build:
	docker build -t print-color .

run: start
	./test_stepfunctions.sh