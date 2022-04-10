using DataCurator
using Test
using Logging
using Random
using Images
using CSV
using DataFrames

@testset "DataCurator.jl" begin

    @testset "aggregator_pattern" begin
        c = global_logger()
        global_logger(NullLogger())
        l = make_shared_list()
        adder = x::AbstractString -> add_to_file_list(x, l)
        transformer = identity
        aggregator = shared_list_to_file
        Q = make_aggregator("L", l, adder, aggregator, transformer)
        Q.transformer == identity
        Q.transformer(1) == 1
        Q.adder("1")
    end

    @testset "testslicing" begin
        IN="testdir"
        delete_folder("outdir")
        delete_folder(IN)
        mkdir(IN)
        A  = zeros(30,30,30)
        Images.save(joinpath(IN, "ABC_1.tif"), A)
        res = create_template_from_toml(joinpath("..","example_recipes","image_roi.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)

        @test isfile(joinpath(IN, "ABC_1.tif"))
        a = Images.load(joinpath(IN, "abc_1.tif"))
        @test size(a) == (6, 30, 4)
        delete_folder(IN)
    end

    @testset "pipelineops" begin
        IN="testdir"
        delete_folder(IN)
        mkdir(IN)
        A  = rand(40,40)./10
        A[10:20, 10:30] .= min.(1, 0.5 .+ rand(11, 21))
        Images.save(joinpath(IN, "ABC_1.tif"), A)
        res = create_template_from_toml(joinpath("..","example_recipes","image_pipeline.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        @test isfile(joinpath(IN, "abc_1.tif"))
        ~iszero(Images.load(joinpath(IN, "abc_1.tif")))
        rm(IN, recursive=true)
    end

    @testset "saved_actions" begin

        IN="testdir"
        delete_folder("outputdir")
        delete_folder(IN)
        mkdir(IN)
        A  = zeros(30,30,30)
        Images.save(joinpath(IN, "ABC_1.tif"), A)
        res = create_template_from_toml(joinpath("..","example_recipes","saved_actions.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)

        @test ~isfile(joinpath(IN, "ABC_1.tif"))
        @test isdir("outputdir")
        @test length(readlines(joinpath("outputdir", "errors.txt")))==1
        delete_folder("outputdir")
    end

    @testset "loadsavecontent" begin
        c = global_logger()
        global_logger(NullLogger())
        a = zeros(3,3,3)
        af = "test.tif"
        remove(af)
        Images.save(af, a)
        L = load_content(af)
        @test size(L) == (3,3,3)
        save_content(L, "q.tif")
        @test isfile("q.tif")
        remove(af)
        remove("q.tif")
        d = DataFrame(zeros(3,3), :auto)
        save_content(d, "2.csv")
        CSV.write("1.csv",  DataFrame(zeros(3,3), :auto))
        e = load_content("1.csv")
        @test d == e
        @test d == load_content("2.csv")
    end

    @testset "reductions" begin
        c = global_logger()
        global_logger(NullLogger())
        a = zeros(3,3,3)
        Images.save("test.tif", a)
        X = Images.load("test.tif")
        Y = reduce_image(X, ["maximum", 1])
        @test size(Y) == (1,3,3)
        Y = reduce_image(X, ["maximum", 3])
        @test size(Y) == (3,3,1)
    end

    @testset "transform_api" begin
        c = global_logger()
        global_logger(NullLogger())
        remove("test.tif")
        remove("TEST.tif")
        Images.save("TEST.tif", zeros(3,3))
        transform_wrapper("TEST.tif", tolowercase, identity, mode_move)
        @test isfile("TEST.tif") == false
        @test isfile("test.tif") == true
        remove("test.tif")
        remove("TEST.tif")
        Images.save("TEST.tif", zeros(3,3))
        transform_wrapper("TEST.tif", tolowercase, identity, mode_copy)
        @test isfile("TEST.tif") == true
        @test isfile("test.tif") == true
        remove("test.tif")
        remove("TEST.tif")
        Images.save("TEST.tif", zeros(3,3))
        transform_wrapper("TEST.tif", tolowercase, identity, mode_inplace)
        @test isfile("TEST.tif") == false
        @test isfile("test.tif") == true
        remove("test.tif")
        remove("TEST.tif")
    end

    @testset "tmp" begin
        c = global_logger()
        global_logger(NullLogger())
        for _ in 1:1000
            a="a.test"
            if isfile(a)
                rm(a)
            end
            touch(a)
            q = tmpcopy(a)
            @test isfile(q)
            @test isfile(a)
            rm(q)
            rm(a)
        end
    end

    @testset "mode" begin
        c = global_logger()
        global_logger(NullLogger())
        a = "test.txt"
        if isfile(a)
            rm(a)
        end
        touch(a)
        q = tmpcopy(a)
        b = "new.txt"
        if isfile(b)
            rm(b)
        end
        mode_copy(a, q, b)
        @test isfile(a)
        @test ~isfile(q)
        @test isfile(b)
        rm(b)
        q = tmpcopy(a)
        mode_move(a, q, b)
        @test ~isfile(a)
        @test ~isfile(q)
        @test isfile(b)
        touch(a)
        q = tmpcopy(a)
        mode_inplace(a, q, a)
        remove(a)
        remove(q)
        remove(b)
    end

    @testset "pattern_removal" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = mktempdir()
        T1= "20x_NR12-55_16_P1_Cy3-FITC-DAPI-Image Export-28_h0t0z0c0-3x0-2048y0-2048.tif"
        T2= "20x_2008-037_27_C1_Cy3-FITC-DAPI-Image Export-21_h0t0z0c0-3x0-2048y0-2048.tif"
        F1 = touch(joinpath(IN, T1))
        F2 = touch(joinpath(IN, T2))
        R = remove_pattern(F1, "DAPI")
        @test contains(F1, "DAPI")
        @test ~contains(R, "DAPI")
        R = remove_pattern(F2, "DAPI")
        @test contains(F2, "DAPI")
        @test ~contains(R, "DAPI")
        rm(IN; recursive=true)
    end

    @testset "extend_removal" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = mktempdir()
        T1= "20x_NR12-55_16_P1_Cy3-FITC-DAPI-Image Export-28_h0t0z0c0-3x0-2048y0-2048.tif"
        T2= "20x_2008-037_27_C1_Cy3-FITC-DAPI-Image Export-21_h0t0z0c0-3x0-2048y0-2048.tif"
        F1 = touch(joinpath(IN, T1))
        F2 = touch(joinpath(IN, T2))
        Q = remove_from_to(T1, "DAPI", ".tif"; inclusive_first=false)
        Z = "20x_NR12-55_16_P1_Cy3-FITC-DAPI.tif"
        @test Q == Z
        Q = remove_from_to(F1, "DAPI", ".tif"; inclusive_first=false)
        @test Q == joinpath(IN, Z)
        A = remove_from_to_extension(T1, "DAPI"; inclusive_first=false)
        @test Q == joinpath(IN, A)
        rm(IN; recursive=true)
    end

    @testset "tf-copy+remove" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = mktempdir()
        T1= "20x_NR12-55_16_P1_Cy3-FITC-DAPI-Image Export-28_h0t0z0c0-3x0-2048y0-2048.tif"
        T2= "20x_2008-037_27_C1_Cy3-FITC-DAPI-Image Export-21_h0t0z0c0-3x0-2048y0-2048.tif"
        F1 = touch(joinpath(IN, T1))
        F2 = touch(joinpath(IN, T2))
        f = ["transform_copy", ["remove_from_to_extension_inclusive", "DAPI"]]
        Q = decode_function(f, Dict("regex"=>true))
        Z=Q(F1)
        @test ~contains(Z, "DAPI")
        f = ["transform_copy", ["remove_from_to_extension_exclusive", "DAPI"]]
        A=decode_function(f, Dict("regex"=>true))
        B=A(F1)
        @test contains(B, "DAPI")
        rm(IN; recursive=true)
    end

    @testset "RMV" begin
        c = global_logger()
        global_logger(NullLogger())
        a = ["remove_from_to", "DAPI", ".tif"]
        z = decode_function(a, Dict("regex"=>true))("DAPI-Unage.tif")
        @test z==".tif"


        # _remove_from_to("DAPI-Unage.tif", "DAPI", ".tif")
    end

    @testset "rmv_aliases" begin
        c = global_logger()
        global_logger(NullLogger())
        F = "ABC_CDE.txt"
        R1=remove_from_to_inclusive(F, "_", ".txt")
        @test R1=="ABC"
        R2=remove_from_to_exclusive(F, "_", ".txt")
        @test R2=="ABC_.txt"
        F = "ABC_CDE.txt"
        R1=remove_from_to_extension_inclusive(F, "_")
        @test R1=="ABC.txt"
        R2=remove_from_to_extension_exclusive(F, "_")
        @test R2=="ABC_.txt"
    end

    @testset "sl_issue2" begin
        c = global_logger()
        global_logger(NullLogger())
        IN="testdir"
        delete_folder(IN)
        mkdir(IN)
        touch(joinpath(IN, "20x_2008-037_27_C1_Cy3-FITC-DAPI-Image Export-21_h0t0z0c0-3x0-2048y0-2048.tif"))
        Q = readdir("testdir") |> collect
        @test length(Q) == 1
        res = create_template_from_toml(joinpath("..","example_recipes","remove_pattern.toml"))
        c, t = res
        t[1].action("abc.txt")
        cts, cls, rv = delegate(c, t)
        Q = readdir("testdir") |> collect
        @test length(Q) == 2
        rm(IN; recursive=true)
    end

    @testset "dataframe_ops" begin
        IN = "testdir"
        isdir(IN) ? rm(IN, recursive=true) : nothing
        mkpath(IN)
        csv1 = CSV.write(joinpath(IN, "One.csv"),  DataFrame(zeros(3,3), :auto))
        csv2 = CSV.write(joinpath(IN, "Two.csv"),  DataFrame(zeros(3,3), :auto))
        res = create_template_from_toml(joinpath("..", "example_recipes", "dataframeops.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        X = CSV.read(joinpath(IN,"one.csv"), DataFrame)
        @test size(X) == (3,3)
        @test sum(sum(eachcol(X))) == 0
    end

    @testset "content_and_names" begin
        c = global_logger()
        global_logger(NullLogger())
        IN="testdir"
        delete_folder(IN)
        mkdir(IN)
        D = zeros(3,3)
        D[2,2] = 0.75
        D[2,1] = 0.5
        Images.save(joinpath(IN, "TEST.tif"), D)
        res = create_template_from_toml(joinpath("..","example_recipes","content_and_naming.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        Q = readdir(IN) |> collect
        @test length(Q) == 2
        E = Images.load(joinpath(IN,"test.tif"))
        @test sum(E) == 1
        @test size(E) == (3,1)
        rm(IN; recursive=true)
    end

    @testset "describe" begin
        c = global_logger()
        global_logger(NullLogger())
        IN="testdir"
        delete_folder(IN)
        mkdir(IN)
        Images.save(joinpath(IN, "1.tif"), rand(20, 20, 5))
        Images.save(joinpath(IN, "2.tif"), rand(20, 20, 5))
        res = create_template_from_toml(joinpath("..","example_recipes","aggregate_describe.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)

        df = CSV.read("image_stats.csv", DataFrame)
        @test size(df)[1] == 10
        rm("image_stats.csv")
        # should be 10, 1 row per slice, 3 axis
        rm(IN; recursive=true)
    end

    @testset "aggregate_by_prefix" begin
        c = global_logger()
        global_logger(NullLogger())
        IN="testdir"
        delete_folder(IN)
        mkdir(IN)
        Images.save(joinpath(IN, "abc_1.tif"), zeros(4,4))
        Images.save(joinpath(IN, "abc_2.tif"), ones(4,4))
        Images.save(joinpath(IN, "abc_3.tif"), ones(4,4)./2)
        Images.save(joinpath(IN, "cde_1.tif"), zeros(4,4))
        Images.save(joinpath(IN, "cde_2.tif"), ones(4,4))
        res = create_template_from_toml(joinpath("..","example_recipes","aggregate_stack_images_by_prefix.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        A = Images.load("abc.tif")
        @test size(A) == (4,4,3)
        D = Images.load("cde.tif")
        @test size(D) == (4,4,2)
        rm(IN, recursive=true)
        remove("abc.tif")
        remove("cde.tif")
    end

    @testset "list_table" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = "testdir"
        isdir(IN) ? rm(IN, recursive=true) : nothing
        mkpath(IN)
        using CSV, DataFrames
        csv1 = CSV.write(joinpath(IN, "1.csv"),  DataFrame(zeros(3,3), :auto))
        csv2 = CSV.write(joinpath(IN, "2.csv"),  DataFrame(zeros(3,3), :auto))
        # touch("/dev/shm/inputspaces/2/3/4 .txt")
        # touch("/dev/shm/inputspaces/top .txt")
        # mkpath("/dev/shm/flattened_path")
        res = create_template_from_toml(joinpath("..","example_recipes","collect_csvs_in_table.toml"))
        c, t = res
        # t[1].action(csv1)
        cts, cls, rv = delegate(c, t)
        df = CSV.read("table.csv", DataFrame)
        @test size(df) == (6,3)
    end

    @testset "list_stack_images" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = "testdir"
        isdir(IN) ? rm(IN, recursive=true) : nothing
        mkpath(IN)
        using CSV, DataFrames
        Images.save(joinpath(IN, "1.tif"), zeros(3,3))
        Images.save(joinpath(IN, "2.tif"), zeros(3,3))

        # touch("/dev/shm/inputspaces/2/3/4 .txt")
        # touch("/dev/shm/inputspaces/top .txt")
        # mkpath("/dev/shm/flattened_path")
        res = create_template_from_toml(joinpath("..","example_recipes","aggregate_new_api_images.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        isfile("3dstack.tif")
        size(Images.load("3dstack.tif")) == (3,3,2)
    end

    @testset "max_project" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = "testdir"
        isdir(IN) ? rm(IN, recursive=true) : nothing
        mkpath(IN)
        using CSV, DataFrames
        Images.save(joinpath(IN, "1.tif"), zeros(3,3))
        Images.save(joinpath(IN, "2.tif"), zeros(3,3))

        # touch("/dev/shm/inputspaces/2/3/4 .txt")
        # touch("/dev/shm/inputspaces/top .txt")
        # mkpath("/dev/shm/flattened_path")
        res = create_template_from_toml(joinpath("..","example_recipes","max_projection_2d.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        isfile("3dstack.tif")
        sum(Images.load("3dstack.tif")) == 9
    end

    @testset "list_table_napi" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = "testdir"
        isdir(IN) ? rm(IN, recursive=true) : nothing
        mkpath(IN)
        using CSV, DataFrames
        csv1 = CSV.write(joinpath(IN, "1.csv"),  DataFrame(zeros(3,3), :auto))
        csv2 = CSV.write(joinpath(IN, "2.csv"),  DataFrame(zeros(3,3), :auto))
        # touch("/dev/shm/inputspaces/2/3/4 .txt")
        # touch("/dev/shm/inputspaces/top .txt")
        # mkpath("/dev/shm/flattened_path")
        res = create_template_from_toml(joinpath("..","example_recipes","aggregate_new_api.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        df = CSV.read("table.csv", DataFrame)
        @test size(df) == (6,1)
    end

    @testset "lists_outpath" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = "testdir"
        isdir(IN) ? rm(IN, recursive=true) : nothing
        mkpath(IN)
        using CSV, DataFrames
        csv1 = CSV.write(joinpath(IN, "1.csv"),  DataFrame(zeros(3,3), :auto))
        csv2 = CSV.write(joinpath(IN, "2.csv"),  DataFrame(zeros(3,3), :auto))
        # touch("/dev/shm/inputspaces/2/3/4 .txt")
        # touch("/dev/shm/inputspaces/top .txt")
        # mkpath("/dev/shm/flattened_path")
        res = create_template_from_toml(joinpath("..","example_recipes","input_output_lists.toml"))
        c, t = res
        # t[1].action(csv1)
        cts, cls, rv = delegate(c, t)
        inl = readlines("infiles.txt")
        otl = readlines("outfiles.txt")
        for ot in otl
            # @error ot
            @test contains(ot, "outpath")
        end
        for it in inl
            @test ~contains(it, "outpath")
        end
        # df = CSV.read("table.csv", DataFrame)
        # @test size(df) == (6,3)
    end

    @testset "logmsg" begin
        ac = ["log_to_file_with_message", "log.txt", "expecting Series xyz"]
        # a = decode_symbol(["log_to_file_with_message", "log.txt", "expecting Series xyz"], Dict("regex"=>true))
        @test ~isnothing(decode_symbol(ac, Dict("regex"=>true)))
    end

    @testset "nested" begin
        a = decode_symbol([["all", "show_warning", "show_warning"]], Dict("regex"=>true))
        @test ~isnothing(a)
    end

    @testset "example_transform_chained" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = "testdir/input_spaces_upper"
        if isdir(IN)
            rm(IN, recursive=true)
        end
        mkpath(IN)
        f1 = joinpath(IN, "aB c.txt")
        touch(f1)
        res = create_template_from_toml(joinpath("..","example_recipes","spaces_to_.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        @test ~isfile(f1)
        @test isfile(joinpath(IN, "ab_c.txt"))
    end

    @testset "testhdf5mat" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = "testdir"
        if isdir(IN)
            rm(IN, recursive=true)
        end
        if isfile("img.hdf5")
            rm("img.hdf5")
        end
        if isfile("csv.mat")
            rm("csv.mat")
        end
        mkpath(IN)
        CSV.write(joinpath(IN, "test.csv"), DataFrame(zeros(3,3),:auto))
        Images.save(joinpath(IN, "test.tif"), zeros(3,3,3))
        res = create_template_from_toml(joinpath("..","example_recipes","export_to_mat_h5.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        @test isfile("img.hdf5")
        @test isfile("csv.mat")
    end

    @testset "tupletypes" begin
        c = global_logger()
        global_logger(NullLogger())
        i = 1
        f = x-> begin; i= i+1;end
        g = x-> begin; i= i+2;end
        h = x-> begin; i=0; end
        nt = make_tuple(iseven, x->apply_all([f,g], x))
        @test nt.condition(2) == true
        nt.action(2)
        @test i == 4
        i = 0
        nt = make_tuple(iseven, x->apply_all([f,g], x), h)
        nt.counteraction(2)
        @test i==0
        nt.action(2)
        @test i==3
        i = 0
        nt = make_tuple(iseven, f, h)
        nt.action(1)
        @test i == 1
        nt.counteraction(1)
        @test i == 0
    end

    @testset "tupledispatch" begin
        c = global_logger()
        global_logger(NullLogger())
        f = x->1
        g = x->2
        e = iseven
        nt = make_tuple([e,f,g]...)
        mt = make_tuple([e,f]...)
        @test mt.action(2) == 1
        @test nt.condition(2) == mt.condition(2)
        @test nt.counteraction(2) == 2
    end

    @testset "dostep" begin
        c = global_logger()
        global_logger(NullLogger())
        f = x->1
        g = x->2
        e = iseven
        nt = make_tuple([e,f,g]...)
        mt = make_tuple([e,f]...)
        @test dostep(2, nt, true) == :proceed
        @test dostep(2, mt, true) == :proceed
        @test dostep(2, nt, false) == :proceed
        @test dostep(2, mt, false) == :proceed
    end

    @testset "tolevel" begin
        c = global_logger()
        global_logger(NullLogger())
        a=to_level([sin], [iseven], [cos];all=true)
        b=to_level([sin],[iseven] ,[cos];all=false)
        c=to_level([sin],[iseven];all=true)
        d=to_level([sin],[iseven];all=false)
        @test a[1].condition(2) == b[1].condition(2)
        @test b[1].condition(2) == d[1].condition(2)
        @test a[1].condition(2) == d[1].condition(2)
    end

    @testset "example_early_exit" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = joinpath("testdir", "void")
        if isdir(IN)
            rm(IN, recursive=true)
        end
        mkpath(IN)
        f1 = joinpath(IN, "c.txt")
        mkpath(joinpath(IN, "deeper"))
        f2 = joinpath(IN, "deeper", "cd.txt")
        touch(f1)
        touch(f2)
        res = create_template_from_toml(joinpath("..","example_recipes","early_exit.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        @test rv == :quit

    end

    @testset "example_transform_chained_2" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = joinpath("testdir","input_spaces_upper")
        if isdir(IN)
            rm(IN, recursive=true)
        end
        mkpath(IN)
        f1 = joinpath(IN, "aB c.txt")
        touch(f1)
        res = create_template_from_toml(joinpath("..","example_recipes","spaces_to_0.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        @test isfile(f1)
        @test isfile(joinpath(IN, "ab_c.txt"))
    end

    @testset "example_hierarchical" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = "testdir"
        isdir(IN) ? rm(IN, recursive=true) : nothing
        mkpath(IN)
        f1 = joinpath(IN, "test.txt")
        touch(f1)
        res = create_template_from_toml(joinpath("..","example_recipes","hierarchical_validation.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        @test isfile(f1)
    end

    @testset "example_csv" begin
        c = global_logger()
        global_logger(NullLogger())
        IN = "testdir"
        isdir(IN) ? rm(IN, recursive=true) : nothing
        mkpath(IN)
        using CSV, DataFrames
        csv1 = CSV.write(joinpath(IN, "1.csv"),  DataFrame(zeros(3,3), :auto))
        csv2 = CSV.write(joinpath(IN, "2.csv"),  DataFrame(zeros(3,3), :auto))
        # touch("/dev/shm/inputspaces/2/3/4 .txt")
        # touch("/dev/shm/inputspaces/top .txt")
        # mkpath("/dev/shm/flattened_path")
        res = create_template_from_toml(joinpath("..","example_recipes","collect_csvs_in_table.toml"))
        c, t = res
        t[1][2]
        cts, cls, rv = delegate(c, t)
        df = CSV.read("table.csv", DataFrame)
        @test size(df) == (6, 3)
    end

    @testset "collapse" begin
        c = global_logger()
        global_logger(NullLogger())
        XF = collapse_functions([sin, cos]; left_to_right=true)
        @test XF(2) == cos(sin(2))
        XF = collapse_functions([sin, cos]; left_to_right=false)
        @test XF(2) == sin(cos(2))
    end

    @testset "example_flatten" begin
        c = global_logger()
        global_logger(NullLogger())
        mkpath("outdir")
        mkpath("testdir/input")
        mkpath("testdir/input/2/3/4/5")
        touch("testdir/input/2/3/4.txt")
        touch("testdir/input/top.txt")
        if isdir("outdir")
            rm("outdir", recursive=true)
        end
        mkpath("outdir")
        res = create_template_from_toml(joinpath("..","example_recipes","flatten.toml"))
        c, t = res
        cts, cls, rv = delegate(c, t)
        @test isfile("outdir/top.txt")
        @test isfile("outdir/4.txt")
    end

    @testset "validate_dataset_hierarchy" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        pt = joinpath(root, "1", "Type 2", "Serie 14")
        mkpath(pt)
        a = zeros(3, 3, 3)
        f1 = joinpath(pt, "channel_1.tif")
        Images.save(f1, a)
        f2 = joinpath(pt, "channel_2.tif")
        Images.save(f2, a)
        isint = x -> ~isnothing(tryparse(Int, basename(x)))
        condition = x->false
        action = x-> @info x
        is3d = x-> length(size(Images.load(x)))==3
        is2d = x-> length(size(Images.load(x)))==3
        valid_channel = x -> occursin(r".*[1,2]\.tif", x)
        valid_cellnr = x->occursin(r"Serie\ [0-9]+", x)
        @test valid_cellnr("Serie 040")
        template = Dict()
        isint = x -> ~isnothing(tryparse(Int, splitpath(x)[end]))
        template[-1] = [(always, x-> quit_on_fail)]
        template[1] = [make_tuple(x-> isdir(x), warn_on_fail)]
        template[2] = [make_tuple(x->all_of([isdir, isint],x), warn_on_fail)]
        template[3] = [make_tuple(x->isdir(x), warn_on_fail)]
        template[4] = [make_tuple(x->all_of([isdir, valid_cellnr],x), warn_on_fail)]
        template[5] = [make_tuple(x->all_of([isfile, valid_channel, is3d],x), warn_on_fail)]
        @test verify_template(root, template; act_on_success=false)==:proceed
        rm(root, force=true, recursive=true)
        global_logger(c)
    end

    @testset "l2f" begin
        c = global_logger()
        global_logger(NullLogger())
        r = mktempdir()
        log_to_file("a", joinpath(r,"abc.txt"))
        @test isfile(joinpath(r,"abc.txt"))
    end


    @testset "decoding" begin
        c = global_logger()
        global_logger(NullLogger())
        s = decode_symbol("warn_on_fail", Dict())
        @test ~isnothing(s)
        s = decode_symbol("abc", Dict())
        @test isnothing(s)
    end

    @testset "sc" begin
        c = global_logger()
        global_logger(NullLogger())
        TF = "aBc"
        @test has_lower(TF)
        @test has_upper(TF)
        @test ~is_lower(TF)
        @test ~is_upper(TF)
    end


    @testset "regex" begin
        c = global_logger()
        global_logger(NullLogger())
        T = "123 Serie"
        @test ~isnothing(read_prefix_int(T))
        @test isnothing(read_postfix_int(T))
        @test isnothing(read_prefix_int(reverse(T)))
        @test ~isnothing(read_postfix_int(reverse(T)))
        T = "123.345 Series"
        @test ~isnothing(read_prefix_float(T))
        @test isnothing(read_postfix_float(T))
        @test isnothing(read_prefix_float(reverse(T)))
        @test ~isnothing(read_postfix_float(reverse(T)))
    end

    @testset "incrementer" begin
        c = global_logger()
        global_logger(NullLogger())
        ec, count_error = generate_counter(true)
        count_error(2)
        @test read_counter(ec) == 1
        sc, count_size = generate_counter(true; incrementer=size_of_file)
        n = zeros(20,20,20)
        nf = joinpath(mktempdir(), "test.tif")
        Images.save(nf, n)
        count_size("/dev/shm/noexist.txtst")
        @test read_counter(sc) == 0
        count_size(nf)
        @test read_counter(sc) == 13248
    end


    @testset "nfiles" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        t = joinpath(root, "1.txt")
        @test ~n_files_or_more(root, 1)
        @test ~has_n_files(root, 1)
        @test less_than_n_files(root, 1)
        touch(t)
        @test n_files_or_more(root, 1)
        @test has_n_files(root, 1)
        @test less_than_n_files(root, 2)
    end

    @testset "destructive" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        for i in [1]
            for s in [14]
                pt = joinpath(root, "$i", "Type 2", "Serie $s")
                mkpath(pt)
                a = zeros(3, 3, 3)
                f0 = joinpath(pt, "channel_0.tif")
                Images.save(f0, a)
                f1 = joinpath(pt, "channel_1.tif")
                Images.save(f1, a)
                f2 = joinpath(pt, "channel_2.tif")
                Images.save(f2, a)
            end
        end
        s, ct = generate_counter(true)
        X = make_tuple(x -> endswith(x, "0.tif"), x->apply_all([ct, delete_file],x) )
        # template = [( x -> endswith(x, "0.tif"), x->apply_all([ct, delete_file],x))]
        template = [X]
        @test isfile(joinpath(root, "1", "Type 2", "Serie 14", "channel_0.tif"))
        verify_template(root, template; act_on_success=true)
        @test ~isfile(joinpath(root, "1", "Type 2", "Serie 14", "channel_0.tif"))
        @test read_counter(s) == 1
        s, ct = generate_counter(true)
        template = [X]
        # template = [( x -> endswith(x, "0.tif"), x->apply_all([ct, delete_file],x))]
        verify_template(root, template; act_on_success=true)
        @test ~isfile(joinpath(root, "1", "Type 2", "Serie 14", "channel_0.tif"))
        @test read_counter(s) == 0

    end

    @testset "shortcodes" begin
        c = global_logger()
        global_logger(NullLogger())
        rt = mktempdir()
        z = zeros(3,3,3)
        FN = joinpath(rt, "file.tif")
        Images.save(FN, z)
        @test isfile(FN)
        @test is_img(FN)
        @test is_3d_img(FN)
        @test ~ has_n_files(2, FN)
        has_n_files(rt, 2)
    end

    @testset "movelink" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        node = joinpath(root, "a", "b")
        mkpath(node)
        FL = joinpath(node, "Q.txt")
        touch(FL)
        # mkpath(node)
        newroot = mktempdir()
        # mkpath(newroot)
        newpath = new_path(root, node, newroot)
        np = copy_to(node, root, newroot)
        @test isdir(np)
        newpath = new_path(root, root, newroot)
        @test newpath == root
        rm(root, recursive=true, force=true)
    end

    @testset "movecopy" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        pt = joinpath(root, "1", "Type 2", "Serie 14")
        newroot = mktempdir()
        mkpath(pt)
        move_to(pt, root, newroot)
        qt = joinpath(newroot, "1", "Type 2", "Serie 14")
        @test ispath(qt)
        @test ~ispath(pt)
        rm(root, recursive=true)
        rm(newroot, recursive=true)
        root = mktempdir()
        pt = joinpath(root, "1", "Type 2", "Serie 14")
        fl = joinpath(pt, "test.txt")
        # touch(joinpath(pt, "test.txt"))
        newroot = mktempdir()
        mkpath(pt)
        touch(fl)
        qt = joinpath(newroot, "1", "Type 2", "Serie 14")
        nl = joinpath(qt, "test.txt")
        move_to(pt, root, newroot)
        @test ~isfile(fl)
        isfile(joinpath(qt, "test.txt"))
        @test ~ispath(pt)
        rm(root, recursive=true)
        rm(newroot, recursive=true)
        root = mktempdir()
        pt = joinpath(root, "1", "Type 2", "Serie 14")
        fl = joinpath(pt, "test.txt")
        # touch(joinpath(pt, "test.txt"))
        newroot = mktempdir()
        mkpath(pt)
        touch(fl)
        qt = joinpath(newroot, "1", "Type 2", "Serie 14")
        nl = joinpath(qt, "test.txt")
        copy_to(pt, root, newroot)
        @test isfile(fl)
        @test isfile(joinpath(qt, "test.txt"))
        @test ispath(pt)
        rm(root, recursive=true)
        rm(newroot, recursive=true)
    end


    @testset "relativecopy" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        pt = joinpath(root, "1", "Type 2", "Serie 14")
        fl = joinpath(pt, "test.txt")
        # touch(joinpath(pt, "test.txt"))
        newroot = mktempdir()
        mkpath(pt)
        touch(fl)
        qt = joinpath(newroot, "Serie 14")
        nl = joinpath(qt, "test.txt")
        copy_to(pt, root, newroot; keeprelative=false)
        @test ispath(qt)
        @test isfile(fl)
        # @test isfile(joinpath(newroot, "test.txt"))
        @test ispath(pt)
        rm(root, recursive=true)
        rm(newroot, recursive=true)
    end

    @testset "movelinkfile" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        node = joinpath(root, "a", "b")
        mkpath(node)
        node = joinpath(node, "Q.txt")
        touch(node)
        # mkpath(node)
        newroot = mktempdir()
        # mkpath(newroot)
        # newpath = new_path(root, node, newroot)
        np = copy_to(node, root, newroot)
        # @test isdir(np)
        # newpath = new_path(root, root, newroot)
        @test isfile(np)
        rm(root, recursive=true, force=true)
    end

    @testset "validate_dataset" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        pt = joinpath(root, "1", "Type 2", "Serie 14")
        mkpath(pt)
        a = zeros(3, 3, 3)
        f1 = joinpath(pt, "channel_1.tif")
        Images.save(f1, a)
        f2 = joinpath(pt, "channel_2.tif")
        Images.save(f2, a)
        isint = x -> ~isnothing(tryparse(Int, basename(x)))
        condition = x->false
        action = x-> @info x
        is3d = x-> length(size(Images.load(x)))==3
        is2d = x-> length(size(Images.load(x)))==3
        valid_channel = x -> occursin(r".*[1,2]\.tif", x)
        valid_cellnr = x->occursin(r"Serie\ [0-9]+", x)
        @test valid_cellnr("Serie 040")
        Q = make_counter()#ParallelCounter(zeros(Int64, Base.Threads.nthreads()))
        countsize = x -> increment_counter(Q; inc=filesize(x))
        template = [make_tuple(isfile, countsize)]
        # template = [(isfile, countsize)]
        verify_template(root, template; act_on_success=true)
        @test sum(Q.data) == 1648
        Q = make_counter(true)
        verify_template(root, template; act_on_success=true, parallel_policy="parallel")
        @test   sum(Q.data) == 1648
        rm(root, force=true, recursive=true)
        global_logger(c)
    end

    @testset "transformer" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        N = 1
        mkpath(joinpath(root, ["$i" for i in 1:N]...))
        for i in 1:N
                touch(joinpath(root, ["$i" for i in 1:i]..., " $i .txt"))
        end
        condition = x -> ~contains(x, ' ')
        no_space = x -> replace(x, ' ' => '_')
        action = x -> transform_inplace(x, no_space)
        has_whitespace = condition
        space_to_ = action
        X = make_tuple(has_whitespace, space_to_)
        @test transform_template(root, [X]) == :proceed
        verify_template(root, [X]) == :proceed
        rm(root, recursive=true, force=true)
        global_logger(c)
    end

    @testset "transform" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        mkpath(joinpath(root, "a"))
        pt = joinpath(root, "a")
        @test isdir(pt)
        file = joinpath(root, "a", "a.txt")
        touch(file)
        @test isfile(file)
        nf = transform_copy(file, x->x)
        @test isfile(nf)
        up = x -> uppercase(x)
        nf = transform_inplace(file, up)
        @test ~isfile(file)
        @test isfile(nf)
        nd = transform_copy(pt, up)
        @test isdir(nd)
        @test isdir(pt)
        rm(root, recursive=true, force=true)
        root = mktempdir()
        PT = joinpath(root, "a")
        mkpath(PT)
        nf = transform_inplace(PT, up)
        @test isdir(nf)
        @test ~isdir(PT)
        rm(root, recursive=true, force=true)
        global_logger(c)
    end

    @testset "traversal" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        # root = "/dev/shm/test"
        C = [11, 21, 41]
        for (j,N) in enumerate([5, 10, 20])
            mkpath(joinpath(root, ["$i" for i in 1:N]...))
            for i in 1:N
                touch(joinpath(root, ["$i" for i in 1:i]..., "$i.txt"))
            end
            visitor = x -> ~isnothin(tryparse(Int, basename(x)))
            vts = x -> @debug x
            topdown(root, expand_filesystem, vts)
            bottomup(root, expand_filesystem, vts)
            i = Threads.Atomic{Int}(0);
            visitor = x -> Threads.atomic_add!(i, 1)
            topdown(root, expand_filesystem, visitor)
            @test i[] ==  C[j]
            i = Threads.Atomic{Int}(0);
            bottomup(root, expand_filesystem, visitor)
            @test i[] == C[j]
            rm(root, force=true, recursive=true)
        end
        global_logger(c)

    end

    @testset "exittest" begin
        c = global_logger()
        global_logger(NullLogger())
        root = mktempdir()
        # root = "/dev/shm/test"
        C = [41, 100]
        for (j,N) in enumerate([20, 100])
            mkpath(joinpath(root, ["$i" for i in 1:N]...))
            for i in 1:N
                touch(joinpath(root, ["$i" for i in 1:i]..., "$i.txt"))
            end
            i = Threads.Atomic{Int}(0);
            visitor = x -> begin Threads.atomic_add!(i, 1); (rand() > 0.5) ? (return :quit) : (return :proceed); end
            topdown(root, expand_filesystem, visitor)
            @test i[] <  C[j]
            i = Threads.Atomic{Int}(0);
            bottomup(root, expand_filesystem, visitor)
            @test i[] < C[j]
            rm(root, force=true, recursive=true)
        end
        global_logger(c)

    end


    @testset "fuzz" begin
        # warnquit = x -> begin @warn x; return :quit; end
        N = 100
        c = global_logger()
        global_logger(NullLogger())
        import Random
        Random.seed!(42)
        for i in 1:N
            root = mktempdir()
            # for (j,N) in enumerate([N])
            M = rand(10:20)
            mkpath(joinpath(root, ["$i" for i in 1:M]...))
            for i in 1:M
                touch(joinpath(root, ["$i" for i in 1:i]..., "$i.txt"))
            end
            # i = Threads.Atomic{Int}(0);
            X = make_tuple(x->false, quit_on_fail)
            Y = make_tuple(x->false, warn_on_fail)
            q=verify_template(root, [X])
            @test q == :quit
            q=verify_template(root, [Y])
            @test q == :proceed
            rm(root, force=true, recursive=true)
        end
        global_logger(c)

        # end
    end

    @testset "hierarchical" begin
        N = 500
        c = global_logger()
        global_logger(NullLogger())
        Random.seed!(42)
        for i in 1:N
            root = mktempdir()
            # for (j,N) in enumerate([N])
            M = rand(10:10)
            mkpath(joinpath(root, ["$i" for i in 1:M]...))
            for i in 1:M
                touch(joinpath(root, ["$i" for i in 1:i]..., "$i.txt"))
            end
            # i = Threads.Atomic{Int}(0);
            X = make_tuple(x->false, quit_on_fail)
            q=verify_template(root, [X])
            @test q == :quit
            Y= make_tuple(x->false, warn_on_fail)
            q=verify_template(root, [Y])
            @test q == :proceed
            template = [Y]
            templater = Dict([(-1, template), (1, template)])
            z=verify_template(root, templater; traversalpolicy=topdown)
            @test z == :proceed
            z=verify_template(root, template; traversalpolicy=topdown)
            @test z == :proceed
            templater = Dict([(1, template)])
            z=verify_template(root, templater; traversalpolicy=topdown)
            @test z == :proceed
            templater = Dict([(i, template) for i in 1:M])
            z=verify_template(root, templater; traversalpolicy=topdown)
            @test z == :proceed
            z=verify_template(root, templater; traversalpolicy=topdown, parallel_policy="parallel")
            @test z == :proceed
            rm(root, force=true, recursive=true)
        end
        global_logger(c)
    end


end
