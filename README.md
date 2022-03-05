# DataCurator

A set of functions to verify a user defined template on a dataset, and/or execute arbitrary actions (copy/extract/correct/rename), with the aim to increase reproducible data curation recipes.

## Motivation

##### Lets data scientists focus on algorithm development, making sure data layout will be pristine.

##### Lets users verify a dataset is correctly configured, and if needed corrected, before using a complex pipeline.

##### Lets reviewers verify how **exactly** you curated data, and reproduce it instantly, portably.

## Why not use existing tools?
Unix especially has an enormous array of tools available to do tasks like this, with regex pattern matching, piping, combining tools, even parallelization with xargs, or dedicated tools like glost or gnu parallel.
The problem with them is that they require a highly skilled user to express what are usually requirements fairly quickly described in plain English.
On Windows you'd need to switch to WSL2, or PowerShell, losing portability. Even for UNIX tools, and even if you religiously remain POSIX compliant, there's no guarantee that what you crafted will run on other systems.

## Our approach
We ensure portability by defining the framework in Julia, and only requesting the user to specify simply expressed conditions as a template. By packaging this in singularity we even accommodate those that do not want or can install Julia.

Yet we do not sacrifice power of expression, because advanced users can still define extremely complex templates and actions, and speed is ensured by our multi-threaded API on top of what is already one of the fastest computing platforms around.


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
For example, a basic template for verification would look like
```julia
template = [isinteger]
```
This would test a filesystem hierarchy, and report any file or directory name that does not look like "0", "2" etc.

Let's say you only want to do this test on files, not directories.
```julia
template = [x -> isfile(x) && isinteger(x)]
```


## Curation

## More complex examples
#### Only firing at a certain depth

#### Early exit
```julia
template = [(x -> rand()) > 0.5 ? (return :quit) : (return :proceed)]
```
That's all, as soon as one of your conditions returns the symbol :quit,  
