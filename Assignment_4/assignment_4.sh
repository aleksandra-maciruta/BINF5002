#!/usr/bin/env bash


# Script config for the directory where the downloaded files will reside
DATA_DOWNLOAD_PATH="$(pwd)/bio-data"
# Create the target directory if it does not exist
[ ! -d  "${DATA_DOWNLOAD_PATH}" ] && mkdir -p "${DATA_DOWNLOAD_PATH}"

# Mutable variable that shares the state between the menus
SEQUENCE_FILE_PATH_TO_PROCESS=""

function retry_until_sucess_with_retry_prompt() {
    local script_to_retry="${1}"

    $script_to_retry
    if [ $? -ne 0 ]; then
        while true; do
            read -p "Would you like to retry (Y/n)? " should_retry
            case $should_retry in
                "Y" | "y" | "*( )" | "")
                    $script_to_retry
                    ;;
                *)
                    break
                    ;;
            esac
        done
    fi
}

function download_fasta_file() {
    read -p "Please enter a valid NCBI accession number: " accession_num

    local target_file_path="${DATA_DOWNLOAD_PATH}/${accession_num}.fasta"

    if [ -s "${target_file_path}" ]; then
        echo "The file ${target_file_path} already exists, not downloading it. If you want the script to download the file again, delete the existing file first."
        SEQUENCE_FILE_PATH_TO_PROCESS="${target_file_path}"
    else
        echo "Downloading fasta file for ${accession_num} to ${target_file_path}."
        efetch -db nucleotide -id "$accession_num" -format fasta > "${target_file_path}"

        if [ -s "${target_file_path}" ]; then
            echo "Succesfully downloaded fasta file for ${accession_num} to ${target_file_path}."
            SEQUENCE_FILE_PATH_TO_PROCESS="${target_file_path}"
        else
            echo "Failed to download the fasta file to ${target_file_path}."
            return 1
        fi
    fi
}

function download_fastq_file() {
    read -p "Please enter a valid NCBI accession number: " accession_num

    local target_file_path="${DATA_DOWNLOAD_PATH}/${accession_num}.fastq"

    if [ -s "${target_file_path}" ]; then
        echo "The file ${target_file_path} already exists, not downloading it. If you want the script to download the file again, delete the existing file first."
        SEQUENCE_FILE_PATH_TO_PROCESS="${target_file_path}"
    else
        echo "Downloading fastq file for ${accession_num} to ${target_file_path}"
        fasterq-dump "$accession_num" --concatenate-reads --format fastq --progress --outfile "${target_file_path}"

        if [ -s "${target_file_path}" ]; then
            echo "Succesfully downloaded fastq file for ${accession_num} to ${target_file_path}."
            SEQUENCE_FILE_PATH_TO_PROCESS="${target_file_path}"
        else
            echo "Failed to download the fastq file to ${target_file_path}."
            return 1
        fi
    fi
}

# Processing Menu
function prompt_and_process_sequence_file() {
    local sequence_file_path="${1}"

    while true; do
        echo "This is the processing menu."
        echo "1. Print all attributes in a formatted way, include attribute name before values"
        echo "2. Compute Reverse Complement of Sequences"
        echo "3. Calculate Sequence Lengths"
        echo "4. Compute Average Quality Score (FASTQ only)"
        echo "q. Return to Main Menu"
        read -p "Choose an option (1-4 or q): " option

        case $option in
            1)
                # Print all attributes
                results="$(bioawk -c fastx '{print $name "\n"} $qual "\n" $comment' "${sequence_file_path}" | head -n 5)"
                ;;
            2)
                # TODO: fix
                # Reverse Complement of Sequence
                results="$(seqtk seq -r "${sequence_file_path}")"
                ;;
            3)
                # TODO: fix
                # Sequence Lengths
                results="$(bioawk -c fastx '{print $name, length($seq)}' "${sequence_file_path}")"
                ;;
            4)
                # Average Quality Score
                local sequence_file_name="$(basename -- "${sequence_file_path}")"
                if [ "${sequence_file_name##*.}" == 'fastq' ]; then
                    results="$(bioawk -c fastx '{print ">"$name; print meanqual($qual)}' "${sequence_file_path}" | awk '{if (NR%2==0) sum += $1} END {print sum/(NR/2)}')"
                else
                    echo "Invalid file type. This file is not a fastq file."
                    continue
                fi
                ;;
            q)
                # Return to the file selection menu
                return 0
                ;;
            *)
                echo "Unrecognized option: choose the options provided"
                ;;
        esac

        echo "Results:"
        echo "${results}"
    done
}

# File selection menu
while true; do
    echo "This is the main menu."
    echo "1. Download a FASTA file."
    echo "2. Download a FASTQ file."
    echo "3. Process the downloaded file (${SEQUENCE_FILE_PATH_TO_PROCESS:-"No active file"})."
    echo "q. Exit."
    read -p "Choose an option (1-3 or q): " option

    case $option in
        1)
            # FASTA file
            retry_until_sucess_with_retry_prompt download_fasta_file
            ;;
        2)
            # FASTQ file
            retry_until_sucess_with_retry_prompt download_fastq_file
            ;;
        3)
            # Process the file
            if [ -z "${SEQUENCE_FILE_PATH_TO_PROCESS}" ]; then
                echo "No file is selected for processing. Use options 1 and 2 to select the file that you want to process."
            else
                prompt_and_process_sequence_file "${SEQUENCE_FILE_PATH_TO_PROCESS}"
            fi
            ;;
        q)
            # Exit
            echo "You have exited."
            exit 0
            ;;
        *)
            echo "Unrecognized option: choose the options provided"
            ;;
    esac
done
