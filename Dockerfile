FROM rocker/shiny:4.3.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev libxml2-dev zlib1g-dev curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shiny','ggplot2','caret','caretEnsemble','randomForest','gbm','xgboost','MASS','nnet'), repos='https://cloud.r-project.org')"

RUN mkdir -p /srv/shiny-server/models

RUN MODEL_BASE_URL='https://github.com/imagigato-Banff/Day-zero-biopsies-by-AI/releases/download/models-v1' && \
    echo "Descargando modelos desde ${MODEL_BASE_URL}" && \
    curl -fL --retry 5 --retry-delay 3 -o /srv/shiny-server/models/cv_finalround_list_forSynapse.rds ${MODEL_BASE_URL}/cv_finalround_list_forSynapse.rds && \
    curl -fL --retry 5 --retry-delay 3 -o /srv/shiny-server/models/ah_finalround_list_forSynapse.rds ${MODEL_BASE_URL}/ah_finalround_list_forSynapse.rds && \
    curl -fL --retry 5 --retry-delay 3 -o /srv/shiny-server/models/IFTA_finalround_list_forSynapse.rds ${MODEL_BASE_URL}/IFTA_finalround_list_forSynapse.rds && \
    curl -fL --retry 5 --retry-delay 3 -o /srv/shiny-server/models/Glo_finalround_list_forSynapse.rds ${MODEL_BASE_URL}/Glo_finalround_list_forSynapse.rds && \
    ls -lh /srv/shiny-server/models

COPY . /srv/shiny-server/
RUN chown -R shiny:shiny /srv/shiny-server

EXPOSE 3838
CMD ["/usr/bin/shiny-server"]
