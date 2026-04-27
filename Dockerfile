FROM rocker/shiny:4.3.3

RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev libssl-dev libxml2-dev libgit2-dev \
    && rm -rf /var/lib/apt/lists/*

RUN R -e "install.packages(c('shiny','caret','caretEnsemble','randomForest','gbm','xgboost','MASS','nnet','ggplot2'), repos='https://cloud.r-project.org')"

COPY . /srv/shiny-server/
RUN chown -R shiny:shiny /srv/shiny-server
EXPOSE 3838
CMD ["/usr/bin/shiny-server"]
