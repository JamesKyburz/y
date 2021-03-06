FROM amazonlinux:2 as base

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "installing base stuff" && \
  yum -y groupinstall "Development Tools" && \
  yum install -y pcre-devel xz-devel openssl wget jq python3 && \
  python3 -m pip install -U pip

FROM base as shellcheck

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "installing shellcheck" && \
  scversion="stable" && \
  wget -qO- "https://github.com/koalaman/shellcheck/releases/download/${scversion?}/shellcheck-${scversion?}.linux.x86_64.tar.xz" | tar -xJv && \
  cp "shellcheck-${scversion}/shellcheck" /usr/bin/

FROM base as ag

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "install the silver searcher (ag)" && \
  git clone --depth 1 https://github.com/ggreer/the_silver_searcher.git && \
  (cd the_silver_searcher && ./build.sh && make install)

FROM base as fzf

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "install fzf" && \
  git clone --depth 1 https://github.com/junegunn/fzf.git && \
  (cd fzf; yes | ./install)

FROM base as awscli

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "installing aws-cli" && \
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
  unzip awscliv2.zip && \
  ./aws/install

FROM base as bash-commons

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "bash commons" && \
  git clone --branch v0.1.3 https://github.com/gruntwork-io/bash-commons.git && \
  mkdir -p /opt/gruntwork && \
  cp -r bash-commons/modules/bash-commons/src /opt/gruntwork/bash-commons && \
  chown -R $USER:$(id -gn $USER) /opt/gruntwork/bash-commons

FROM base as go

ENV GOPATH /root/.go
ENV GOROOT /usr/local/go
ENV PATH "/usr/local/go/bin:${PATH}"
ENV PATH "/root/.go/bin:${PATH}"

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "installing go" && \
  curl -L https://golang.org/dl/go1.16.4.linux-amd64.tar.gz -o go.tar.gz && \
  tar -xzf go.tar.gz && \
  mv go /usr/local && \
  rm -rf go.tar.gz && \
  log_info "installing shfmt" && \
  GO111MODULE=on go get mvdan.cc/sh/v3/cmd/shfmt && \
  log_info "installing iamlive" && \
  GO111MODULE=on go get github.com/iann0036/iamlive

FROM base as rust

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "installing rust" && \
  curl https://sh.rustup.rs -sSf -o install && \
  bash install -y && \
  source /root/.cargo/env && \
  log_info "installing bat" && \
  cargo install --locked bat

FROM base as docker

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "installing docker" && \
  amazon-linux-extras install docker && \
  log_info "installing docker-compose" && \
  curl -L https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m) \
    -o /usr/local/bin/docker-compose && \
  chmod +x /usr/local/bin/docker-compose

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "installing unzip" && \
  yum install -y unzip

FROM amazonlinux:2

LABEL maintainer="James Kyburz james.kyburz@gmail.com"

ENV GOPATH /root/.go
ENV GOROOT /usr/local/go
ENV PATH "/usr/local/go/bin:${PATH}"
ENV PATH "/root/.go/bin:${PATH}"
ENV PATH "/root/.cargo/bin:${PATH}"
ENV DENO_INSTALL "/root/.deno"
ENV PATH "$DENO_INSTALL/bin:$PATH"

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "copying from multi-stage steps"

COPY --from=shellcheck /usr/bin/shellcheck /usr/bin/shellcheck
COPY --from=ag /usr/local/bin/ag /usr/local/bin/ag
COPY --from=awscli /usr/local/bin /usr/local/bin
COPY --from=awscli /usr/local/aws-cli /usr/local/aws-cli
COPY --from=docker /usr/bin/docker /usr/bin/docker
COPY --from=docker /usr/local/bin/docker-compose /usr/local/bin/docker-compose
COPY --from=go /root/.go/bin /root/.go/bin
COPY --from=rust /root/.cargo/bin /root/.cargo/bin
COPY --from=bash-commons /opt/gruntwork/bash-commons /opt/gruntwork/bash-commons
COPY --from=fzf /fzf/bin /fzf/bin
COPY --from=fzf /fzf/shell /fzf/shell
COPY --from=fzf /root/.fzf.bash /root/.fzf.bash

RUN \
  log_info() { echo -e "\033[0m\033[1;94m${*}\033[0m"; } && \
  log_info "installing base stuff" && \
  mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH" && \
  mkdir -p /root/.config && \
  chown -R $USER:$(id -gn $USER) /root/.config && \
  yum install -y git python3 jq unzip openssl openssh-clients less && \
  python3 -m pip install -U pip && \
  log_info "installing node" && \
  curl -sL https://rpm.nodesource.com/setup_lts.x | bash - && \
  curl -sL https://dl.yarnpkg.com/rpm/yarn.repo | tee /etc/yum.repos.d/yarn.repo && \
  yum install -y nodejs yarn && \
  log_info "installing latest npm" && \
  npm install npm@latest -g && \
  log_info "installing deno" && \
  curl -fsSL https://deno.land/x/install/install.sh | sh && \
  log_info "installing envsubst" && \
  curl -L https://github.com/a8m/envsubst/releases/download/v1.2.0/envsubst-"$(uname -s)"-"$(uname -m)" -o envsubst && \
  chmod +x envsubst && \
  mv envsubst /usr/local/bin && \
  log_info "installing aws-sam-cli" && \
  pip3 install --no-cache-dir aws-sam-cli && \
  log_info "installing black" && \
  pip3 install --no-cache-dir black && \
  log_info "installing virtualenv" && \
  pip3 install --no-cache-dir virtualenv && \
  log_info "installing awscurl" && \
  pip3 install --no-cache-dir awscurl && \
  log_info "installing yq" && \
  pip3 install --no-cache-dir yq && \
  log_info "installing 1password cli" && \
  curl https://cache.agilebits.com/dist/1P/op/pkg/v1.9.2/op_linux_amd64_v1.9.2.zip -o op.zip && \
  unzip op.zip && \
  chmod +x op && \
  mv op /usr/bin && \
  rm -rf op.zip op.sig && \
  terraform_latest=$(curl https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version') && \
  log_info "installing terraform ${terraform_latest:?}" && \
  curl https://releases.hashicorp.com/terraform/${terraform_latest:?}/terraform_${terraform_latest:?}_linux_amd64.zip -o terraform.zip && \
  unzip terraform.zip && \
  chmod +x terraform && \
  mv terraform /usr/bin && \
  rm -rf terraform.zip && \
  log_info "installing ecs cli" && \
  curl -o /usr/local/bin/ecs-cli https://s3.amazonaws.com/amazon-ecs-cli/ecs-cli-linux-amd64-latest && \
  chmod +x /usr/local/bin/ecs-cli && \
  yum clean all && \
  rm -rf /var/cache/yum && \
  log_info "✨ ops-kitchen installation complete. ✨"

COPY .bashrc /root/.bashrc

RUN echo 'source /root/.fzf.bash' >> /root/.bashrc
