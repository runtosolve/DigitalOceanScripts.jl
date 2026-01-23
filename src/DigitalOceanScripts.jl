module DigitalOceanScripts

using ReadWriteFind, Printf

function generate_droplet_script(remote_working_directory, model_names, local_working_directory, bash_filename, cpus)
    lines = []

    push!(lines, "#!/bin/bash")
    push!(lines, "# Generated for DigitalOcean Droplet")
    
   
    push!(lines, @sprintf "cd %s" remote_working_directory)

    # Abaqus execution lines
    for i in eachindex(model_names)
        
        line = "abaqus job=" * model_names[i] * " cpus=$cpus" * " interactive"
        push!(lines, line)
    end

    ReadWriteFind.write_file(joinpath(local_working_directory, bash_filename), lines)
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

end