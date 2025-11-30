# Hugo-Dash
Fully static, responsive, customizable link collection dashboard created with hugo and tailwind. 

![image](https://user-images.githubusercontent.com/75833801/216191320-7e7a5189-9053-4e3f-85f9-180a08802244.png)

## Used Technologies

- Hugo
- Tailwind CSS
- Font Awesome
- Docker

## Development

### Prerequisites

- hugo
- npm

### Setup

```shell
npm install
```

### Run Local Server

```shell
./run.sh
```

### Build with Docker

```shell
docker build -t hugo-dash . 
```

### Run with Docker

```shell
docker run -it \
-v ~/hugo/data:/src/data \
-v ~/hugo/icons:/src/assets/icons/ \
-p 1313:1313 \
hugo-dash
/
```

## Installation

### docker-compose

There is a [minimal](/docker-compose/minimal/docker-compose.yaml) and a [nginx](/docker-compose/nginx/docker-compose.yaml) configuration.

## Configuration

- [config.yaml](/data/config.yaml)
- [icons](/assets/icons/)
