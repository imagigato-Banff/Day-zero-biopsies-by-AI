FROM rocker/shiny:4.3.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shiny','caret','caretEnsemble','randomForest','gbm','xgboost','MASS','nnet','ggplot2'), repos='https://cloud.r-project.org')"

COPY . /srv/shiny-server/

# Descarga de modelos en tiempo de construcción. No depende de variables de Render.
RUN set -eux; \
    MODEL_BASE_URL='https://github.com/imagigato-Banff/Day-zero-biopsies-by-AI/releases/download/models-v1'; \
    mkdir -p /srv/shiny-server/models; \
    for f in \
      cv_finalround_list_forSynapse.rds \
      ah_finalround_list_forSynapse.rds \
      IFTA_finalround_list_forSynapse.rds \
      Glo_finalround_list_forSynapse.rds; do \
        echo "Descargando modelo: ${f}"; \
        curl -fL --retry 5 --retry-delay 3 --connect-timeout 30 \
          -A 'Mozilla/5.0' \
          -o "/srv/shiny-server/models/${f}" \
          "${MODEL_BASE_URL}/${f}"; \
        test -s "/srv/shiny-server/models/${f}"; \
      done; \
    ls -lh /srv/shiny-server/models

RUN chown -R shiny:shiny /srv/shiny-server
EXPOSE 3838
CMD ["/usr/bin/shiny-server"]
