ARG BUILDER_IMAGE
ARG BASE_IMAGE

FROM ${BUILDER_IMAGE} AS build

ARG TARGETARCH

WORKDIR /work

RUN curl -o /usr/bin/kubectl -L "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/${TARGETARCH}/kubectl";
RUN chmod a+x /usr/bin/kubectl

COPY go.mod go.mod
COPY go.sum go.sum
COPY vendor vendor
COPY cmd/nvdrain cmd/nvdrain

RUN CGO_ENABLED=1 GOEXPERIMENT=boringcrypto go build -tags fips -o nvdrain ./cmd/nvdrain && go tool nm nvdrain | grep -E 'sig.FIPSOnly'

FROM ${BASE_IMAGE}

LABEL maintainers="Compute"

COPY driver-manager /usr/local/bin
COPY scripts/vfio-manage /usr/local/bin
COPY --from=build /work/nvdrain /usr/local/bin
COPY --from=build /usr/bin/kubectl /usr/bin/kubectl

ENTRYPOINT ["driver-manager", "preflight_check"]
