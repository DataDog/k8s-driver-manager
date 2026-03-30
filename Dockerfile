ARG BUILDER_IMAGE

FROM ${BUILDER_IMAGE} AS build

ARG TARGETARCH

WORKDIR /work

ARG KUBECTL_VERSION=v1.34.5-dd.1

RUN curl -Lfs https://github.com/DataDog/kubernetes/releases/download/${KUBECTL_VERSION}/kubernetes-server-linux-${TARGETARCH}.tar.gz -O
RUN tar -C /usr/local/bin/ --strip-components 3 --exclude '*.tar' --exclude '*.docker_tag' -xvzf kubernetes-server-linux-${TARGETARCH}.tar.gz kubernetes/server/bin/kubectl
RUN chmod 755 /usr/local/bin/kubectl
RUN go tool nm /usr/local/bin/kubectl | grep -E 'sig.FIPSOnly'

COPY go.mod go.mod
COPY go.sum go.sum
COPY vendor vendor
COPY cmd/driver-manager cmd/driver-manager
COPY internal/ internal/

RUN CGO_ENABLED=1 GOEXPERIMENT=boringcrypto go build -tags fips -o driver-manager ./cmd/driver-manager && go tool nm driver-manager | grep -E 'sig.FIPSOnly'

FROM registry.ddbuild.io/images/nvidia-cuda-base:12.9.0

LABEL maintainers="Compute"

COPY scripts/vfio-manage /usr/local/bin
COPY --from=build /work/driver-manager /usr/local/bin
COPY --from=build /usr/local/bin/kubectl /usr/bin/kubectl

ENTRYPOINT ["driver-manager", "preflight_check"]
