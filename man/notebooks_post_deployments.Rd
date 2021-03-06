% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/generated_client.R
\name{notebooks_post_deployments}
\alias{notebooks_post_deployments}
\title{Deploy a Notebook}
\usage{
notebooks_post_deployments(notebook_id, deployment_id = NULL)
}
\arguments{
\item{notebook_id}{integer required. The ID of the owning Notebook}

\item{deployment_id}{integer optional. The ID for this deployment}
}
\value{
A list containing the following elements:
\item{deploymentId}{integer, The ID for this deployment}
\item{userId}{integer, The ID of the owner}
\item{host}{string, Domain of the deployment}
\item{name}{string, Name of the deployment}
\item{dockerImageName}{string, The name of the docker image to pull from DockerHub}
\item{dockerImageTag}{string, The tag of the docker image to pull from DockerHub (default: latest).}
\item{displayUrl}{string, URL that displays the deployed platform object and includes auth token.}
\item{memory}{integer, The memory allocated to the deployment}
\item{cpu}{integer, The cpu allocated to the deployment}
\item{state}{string, The state of the deployment}
\item{stateMessage}{string, A detailed description of the state}
\item{createdAt}{string, }
\item{updatedAt}{string, }
\item{notebookId}{integer, The ID of owning Notebook}
}
\description{
Deploy a Notebook
}
