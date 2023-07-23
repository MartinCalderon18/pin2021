eksctl create cluster \
--name eks-mundos-e \
--region us-east-2 \
--node-type t2.micro \
--with-oidc \
--ssh-access \
--ssh-public-key jenkins \
--managed \
--full-ecr-access \
--zones us-east-2a,us-east-2b,us-east-2c