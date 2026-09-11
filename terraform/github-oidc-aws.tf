resource "aws_iam_role" "github_actions" {
  name = "proj2dr-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = "arn:aws:iam::966981264807:oidc-provider/token.actions.githubusercontent.com"
        }
        Action = "sts:AssumeRoleWithWebIdentity"
       Condition = {
                StringEquals = {
                "token.actions.githubusercontent.com:sub" = "repo:shreemantrau@49795327/azure-project2-cross-cloud-dr@1355079911:ref:refs/heads/main"
            }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}