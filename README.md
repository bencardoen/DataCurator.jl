# DataCurator

A set of functions to verify a user defined template on a dataset, and/or execute arbitrary actions (copy/extract/correct/rename), with the aim to increase reproducible data curation recipes.

## Motivation

##### Lets data scientists focus on algorithm development, making sure data layout will be pristine.

##### Lets users verify a dataset is correctly configured, and if needed corrected, before using a complex pipeline.

##### Lets reviewers verify how **exactly** you curated data, and reproduce it instantly, portably.

In addition to increasing reproducibility, a common task in for example biomedical image analysis is processing of huge, complex datasets on clusters. Cluster compute time is an expensive resource, for which you often need to queue compute jobs hours if not days. Having a compute job fail because 1 file doesn't quite match what your pipeline expects is a costly mistake, so one starts to add failsafes, but these add complexity, and in general each pipeline will have its own expected template of how it expects data.

This package formalizes that step, and makes it so you can focus on the compute part, not the data curation part. So when you do run your code, there'll be no crashes because of unexpected hidden or corrupt files, mismatched metadata, UTF-8 characters in filenames, file encoding, and so forth.

If you read academic papers and have tried reproducing their results, the description of data curation always hides some 'obvious' (to the authors) steps, or steps that only work on their systems, and so forth. The lost time in contacting the authors, if they respond, means fewer papers get reproduced, less software reduced, and fewer algorithms validated by reviewers by running them, not reading them.

## Targets

A **target** is your datastore, in the simplest case a folder.

- Implemented
  - [x] Local Filesystems
- Future
  - [-] Archives
    - [-] JLD
    - [-] HDF5
    - [-] MAT

## Template
A template is a set of conditions that a user specifies as recipe describing the layout of the dataset.

## Verification
Verification is quite simply verifying in place if a dataset confirms to a template, logging when part of the dataset does not match the dataset.

## Curation
