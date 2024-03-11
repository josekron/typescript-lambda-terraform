function deploy {
  TIMESTAMP=$(date +%Y%m%d%H%M%S)
  cd ../lambda/ && \
  # Run the npm commands to transpile the TS to JS:
  npm i && \
  npm run build && \
  npm prune --production && \
  # Copy js files into the dist:
  mkdir -p dist && \
  cp -r ./src/*.js dist/ && \
  cp -r ./node_modules dist/ && \
  cd dist &&\
  find . -name "*.zip" -type f -delete && \
  # Zip code from the dist folder:
  mkdir -p ../../terraform/zips && \
  zip -r ../../terraform/zips/lambda_function_"$TIMESTAMP".zip . && \
  cd .. && rm -rf dist && \
  # Run terraform:
  cd ../terraform && \
  terraform plan -input=false -var lambda_version="$TIMESTAMP" -out=./tfplan && \
  terraform apply -input=false ./tfplan
}

deploy
