ARG BUILDER_IMAGE

FROM ${BUILDER_IMAGE} AS build

ARG TARGETARCH

WORKDIR /work

RUN curl -o /usr/bin/kubectl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl";
RUN chmod a+x /usr/bin/kubectl

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
COPY --from=build /usr/bin/kubectl /usr/bin/kubectl

ENTRYPOINT ["driver-manager", "preflight_check"]
