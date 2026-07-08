module DigitalOceanScripts

using ReadWriteFind, Printf

function generate_droplet_script(remote_working_directory, model_names, local_working_directory, bash_filename, cpus; add_queue_logic=false)
    lines = []

    push!(lines, "#!/bin/bash")
    push!(lines, "# Generated for DigitalOcean Droplet")
    push!(lines, @sprintf "cd %s" remote_working_directory)

    if add_queue_logic
        add_submission_to_queue!(lines)
    end

    # Abaqus execution lines
    for i in eachindex(model_names)
        line = "abaqus job=" * model_names[i] * " cpus=$cpus" * " interactive"
        push!(lines, line)
    end

    ReadWriteFind.write_file(joinpath(local_working_directory, bash_filename), lines)
end

function generate_droplet_script_with_UEL(remote_working_directory, model_names, local_working_directory, bash_filename, uel_filename, cpus; add_queue_logic=false)
    lines = []

    push!(lines, "#!/bin/bash")
    push!(lines, "# Generated for DigitalOcean Droplet")
    push!(lines, @sprintf "cd %s" remote_working_directory)

    if add_queue_logic
        add_submission_to_queue!(lines)
    end

    # Abaqus execution lines
    for i in eachindex(model_names)
        line = "abaqus job=" * model_names[i] * " user=" * uel_filename * " cpus=$cpus" * " interactive"
        push!(lines, line)
    end

    ReadWriteFind.write_file(joinpath(local_working_directory, bash_filename), lines)
end

function add_submission_to_queue!(lines)
    push!(lines, "")
    push!(lines, "# --- Queue logic: wait if another Abaqus job is running ---")
    push!(lines, "CID_FILE=\$(find ~ -name \"*.cid\" 2>/dev/null | head -1)")
    push!(lines, "RUNNING_PID=\$([ -n \"\$CID_FILE\" ] && head -1 \"\$CID_FILE\")")
    push!(lines, "")
    push!(lines, "if [ -n \"\$RUNNING_PID\" ] && kill -0 \$RUNNING_PID 2>/dev/null; then")
    push!(lines, "    echo \"Job running (PID \$RUNNING_PID). Waiting in queue...\"")
    push!(lines, "    while kill -0 \$RUNNING_PID 2>/dev/null; do sleep 60; done")
    push!(lines, "    echo \"Previous job done. Starting now...\"")
    push!(lines, "fi")
    push!(lines, "# --- End queue logic ---")
    push!(lines, "")
end


function deploy_to_droplet(ip_address, remote_working_directory, local_working_directory, bash_filename, model_names)
    println("--- Starting Deployment to DigitalOcean Droplet ---")

    #### Create remote working directory if it doesn't exist
    check_cmd = "[ -d $remote_working_directory ] && echo 'exists' || mkdir -p $remote_working_directory"
    
    result = read(`ssh root@$ip_address $check_cmd`, String)
    
    if occursin("exists", result)
        println("Directory already exists: $remote_working_directory (Skipping creation)")
    else
        println("Created new directory: $remote_working_directory")
    end

    
    #### Upload the .sh script
    local_sh = joinpath(local_working_directory, bash_filename)
    run(`scp $local_sh root@$ip_address:$remote_working_directory/`)
    
    #### Upload .inp files
    for name in model_names
        local_inp = joinpath(local_working_directory, "$name.inp")
        run(`scp $local_inp root@$ip_address:$remote_working_directory/`)
        println("Uploaded: $name.inp")
    end
    
    println("--- Deployment Complete ---")
end

function deploy_to_droplet_with_UEL(ip_address, remote_working_directory, local_working_directory, bash_filename, uel_filename, model_names)
    println("--- Starting Deployment to DigitalOcean Droplet ---")

    #### Create remote working directory if it doesn't exist
    check_cmd = "[ -d $remote_working_directory ] && echo 'exists' || mkdir -p $remote_working_directory"

    result = read(`ssh root@$ip_address $check_cmd`, String)

    if occursin("exists", result)
        println("Directory already exists: $remote_working_directory (Skipping creation)")
    else
        println("Created new directory: $remote_working_directory")
    end


    #### Upload the .sh script
    local_sh = joinpath(local_working_directory, bash_filename)
    run(`scp $local_sh root@$ip_address:$remote_working_directory/`)

    #### Upload the UEL Fortran file
    local_uel = joinpath(local_working_directory, uel_filename)
    run(`scp $local_uel root@$ip_address:$remote_working_directory/`)
    println("Uploaded: $uel_filename")

    #### Upload .inp files
    for name in model_names
        local_inp = joinpath(local_working_directory, "$name.inp")
        run(`scp $local_inp root@$ip_address:$remote_working_directory/`)
        println("Uploaded: $name.inp")
    end

    println("--- Deployment Complete ---")
end

function download_dat_files(ip_address, remote_dir, local_dir)

    local_dat_path = joinpath(local_dir, "dat")
    
    if !isdir(local_dat_path)
        mkpath(local_dat_path)
    end


    remote_source = "root@$(ip_address):$(remote_dir)/*.dat"
    
    println("Downloading .dat files from $ip_address...")

    try

        run(`scp -C $remote_source $local_dat_path`)
        
        println("Download complete!")
        
    catch e
        @error "Download failed." exception=e
    end
end

function download_files(ip_address, remote_dir, local_dir, file_extension)

    local_file_path = joinpath(local_dir, file_extension)
    
    if !isdir(local_file_path)
        mkpath(local_file_path)
    end


    remote_source = "root@$(ip_address):$(remote_dir)/*.$file_extension"
    
    println("Downloading .$file_extension files from $ip_address...")

    try

        run(`scp -C $remote_source $local_file_path`)
        
        println("Download complete!")
        
    catch e
        @error "Download failed." exception=e
    end
end

end