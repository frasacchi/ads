function waitForJobs(jobs, opts)
% waitForJobs  Poll f06 files until all Nastran jobs report END OF JOB or FATAL.
%
% jobs  — struct array with fields:
%           .BinFolder  (string) path to the job's bin folder
%           .SolType    (string) 'sol145' or 'sol146'
arguments
    jobs struct
    opts.PollInterval double = 2;
    opts.Timeout      double = 7200;
    opts.Verbose      logical = true;
end
n       = numel(jobs);
done    = false(n,1);
t0      = tic;
n_prev  = 0;
if opts.Verbose
    fprintf('  [waitForJobs] Waiting for %d Nastran jobs...\n', n);
end
while ~all(done)
    if toc(t0) > opts.Timeout
        error('ADS:Nastran:timeout','Timed out after %.0f s waiting for %d jobs', opts.Timeout, sum(~done));
    end
    for k = 1:n
        if done(k), continue; end
        f06 = fullfile(jobs(k).BinFolder, 'bin', [jobs(k).SolType, '.f06']);
        if ~isfile(f06), continue; end
        fid = fopen(f06,'r');
        if fid < 0, continue; end
        txt = fscanf(fid,'%c');
        fclose(fid);
        if contains(txt,'END OF JOB') || contains(txt,'FATAL ERROR')
            done(k) = true;
        end
    end
    n_done = sum(done);
    if opts.Verbose && n_done > n_prev
        fprintf('  [waitForJobs] %d / %d complete (%.0f s elapsed)\n', n_done, n, toc(t0));
        n_prev = n_done;
    end
    if ~all(done)
        pause(opts.PollInterval);
    end
end
if opts.Verbose
    fprintf('  [waitForJobs] All done in %.1f s\n', toc(t0));
end
end
