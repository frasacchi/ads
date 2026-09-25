function frames = sol146_animate(bin_folder, varargin)
    %SOL146_ANIMATE Animates a SOL 146 transient/gust response by stepping
    %through the time stations, updating the model deformation and CQUAD4
    %element colour at each step. Optionally writes the animation to a video
    %or GIF file. Mirrors the parameter style of `sol146`.
    %
    % Inputs:
    %   - bin_folder : char vector. Project folder containing:
    %                   <bin_folder>/Source/sol146.bdf
    %                   <bin_folder>/bin/sol146.h5
    %
    % Optional name-value pairs:
    %   - 'Subcase'        : int. Subcase to animate. Default 1.
    %   - 'ForceComponent' : char. QUAD4 quantity to colour by. One of
    %                        Nx/Ny/Nxy/Mx/My/Mxy/Fx/Fy. Default 'Mx'.
    %   - 'TimeRange'      : [tStart, tEnd] in seconds. Default [] = full range.
    %   - 'Stride'         : int. Step every N-th time index. Default 1.
    %   - 'Scale'          : real. Deformation scale passed to model.update.
    %                        Default 1.
    %   - 'CLim'           : [cMin, cMax]. Fixed colour limits across the
    %                        animation. Default [] = auto, symmetric about 0
    %                        using max|component| in the chosen time range.
    %   - 'Colormap'       : colormap name or Nx3 RGB matrix. Default 'parula'.
    %   - 'OutputFile'     : char. If non-empty, write animation to this file.
    %                        Format inferred from extension (.mp4 / .avi / .gif).
    %   - 'FrameRate'      : real. FPS for video / inverse delay for GIF.
    %                        Default 30.
    %   - 'Pause'          : real. Extra pause (s) between frames in live
    %                        preview. Default 0.
    %
    % Outputs:
    %   - frames : struct array of captured frames (from getframe). Only
    %              populated if requested with an output argument; otherwise
    %              frames are streamed to the writer / discarded to save RAM.
    %
    % Examples:
    %   sol146_animate('C:\...\ex_ffwt_sol146');
    %
    %   sol146_animate('C:\...\ex_ffwt_sol146', ...
    %       'ForceComponent', 'My', 'Stride', 4, ...
    %       'OutputFile', 'gust_response.mp4', 'FrameRate', 24);
    %
    %   % capture frames for post-processing without writing a file:
    %   F = sol146_animate('C:\...\ex_ffwt_sol146', 'Stride', 10);
    
    arguments
        bin_folder char
    end
    arguments (Repeating)
        varargin
    end
    
    p = inputParser();
    p.addParameter('Subcase',        1,        @(x)isnumeric(x)&&isscalar(x));
    p.addParameter('ForceComponent', 'Mx',     @ischar);
    p.addParameter('TimeRange',      [],       @(x)isempty(x)||(isnumeric(x)&&numel(x)==2));
    p.addParameter('Stride',         1,        @(x)isnumeric(x)&&isscalar(x)&&x>=1);
    p.addParameter('Scale',          1,        @(x)isnumeric(x)&&isscalar(x));
    p.addParameter('CLim',           [],       @(x)isempty(x)||(isnumeric(x)&&numel(x)==2));
    p.addParameter('Colormap',       'parula', @(x)ischar(x)||(isnumeric(x)&&size(x,2)==3));
    p.addParameter('OutputFile',     '',       @ischar);
    p.addParameter('FrameRate',      30,       @(x)isnumeric(x)&&isscalar(x)&&x>0);
    p.addParameter('Pause',          0,        @(x)isnumeric(x)&&isscalar(x)&&x>=0);
    p.parse(varargin{:});
    
    storeFrames = nargout > 0;
    
    % ---- import & initial draw ----
    bdf_path = fullfile(bin_folder, 'Source', 'sol146.bdf');
    h5_path  = fullfile(bin_folder, 'bin',    'sol146.h5');
    model = mni.import_matran(bdf_path, 'ExpandInclude', true);
    model.draw;
    
    % ---- read results ----
    hdf = mni.result.hdf5(h5_path);
    res = hdf.read_dynamic();
    if isempty(res)
        error('sol146_animate:NoResults','No results found in %s', h5_path);
    end
    sc_idx = p.Results.Subcase;
    if sc_idx < 1 || sc_idx > numel(res)
        error('sol146_animate:BadSubcase','Subcase %d requested but only %d available.', ...
            sc_idx, numel(res));
    end
    sub  = res(sc_idx);
    comp = p.Results.ForceComponent;
    if ~isfield(sub,'Quad4Force') || isempty(sub.Quad4Force)
        error('sol146_animate:NoQuad4Forces', 'Subcase %d has no QUAD4 forces.', sc_idx);
    end
    Q = sub.Quad4Force;
    if ~isfield(Q, comp)
        error('sol146_animate:BadComponent', ...
            'Unknown ForceComponent ''%s''. Must be Nx/Ny/Nxy/Mx/My/Mxy/Fx/Fy.', comp);
    end
    if isempty(sub.Displacement)
        error('sol146_animate:NoDisplacement', 'Subcase %d has no displacement output.', sc_idx);
    end
    
    % ---- pick time indices ----
    t = sub.t;
    if isempty(p.Results.TimeRange)
        mask = true(size(t));
    else
        mask = (t >= p.Results.TimeRange(1)) & (t <= p.Results.TimeRange(2));
    end
    in_range  = find(mask);
    t_indices = in_range(1:p.Results.Stride:end);
    nFrames   = numel(t_indices);
    if nFrames < 2
        error('sol146_animate:NoFrames', 'Time selection produced %d frame(s).', nFrames);
    end
    fprintf('Animating %d frames (stride=%d, t = %.4g .. %.4g s, dt_avg = %.4g s)\n', ...
        nFrames, p.Results.Stride, t(t_indices(1)), t(t_indices(end)), ...
        mean(diff(t(t_indices))));
    
    % ---- precompute colour limits ----
    if isempty(p.Results.CLim)
        vmax = max(abs(Q.(comp)(t_indices, :)), [], 'all');
        if vmax == 0, vmax = 1; end
        cLim = [-vmax, vmax];
    else
        cLim = p.Results.CLim;
    end
    
    % ---- precompute index maps (do this once, outside the loop) ----
    [~, qi] = ismember(model.CQUAD4.EID, Q.EIDs);
    keep_q  = qi > 0;
    [~, gi] = ismember(model.GRID.GID, sub.Displacement.IDs);
    keep_g  = gi > 0;
    
    % pre-extract the time history slices we need (faster than indexing into
    % the full result struct on every iteration)
    Dx_hist = sub.Displacement.X(t_indices, :);
    Dy_hist = sub.Displacement.Y(t_indices, :);
    Dz_hist = sub.Displacement.Z(t_indices, :);
    Q_hist  = Q.(comp)(t_indices, :);
    
    % ---- set up axes / colorbar once ----
    hAx = gca;
    hFig = ancestor(hAx, 'figure');
    clim(hAx, cLim);
    colormap(hAx, p.Results.Colormap);
    cb = colorbar(hAx);
    cb.Label.String = comp;
    title_h = title(hAx, '');
    
    % ---- output writer ----
    outFile = p.Results.OutputFile;
    writer  = [];
    isGif   = false;
    if ~isempty(outFile)
        [~, ~, ext] = fileparts(outFile);
        switch lower(ext)
            case '.gif'
                isGif = true;
            case {'.mp4','.m4v'}
                writer = VideoWriter(outFile, 'MPEG-4');
                writer.FrameRate = p.Results.FrameRate;
                open(writer);
            case '.avi'
                writer = VideoWriter(outFile, 'Motion JPEG AVI');
                writer.FrameRate = p.Results.FrameRate;
                open(writer);
            otherwise
                error('sol146_animate:UnknownFormat', ...
                    'Unrecognised output extension ''%s''. Use .mp4, .avi or .gif.', ext);
        end
    end
    
    % ---- allocate frame buffer only if caller requested it ----
    if storeFrames
        frames(nFrames) = struct('cdata', [], 'colormap', []);
    else
        frames = [];
    end
    
    % ---- main animation loop ----
    nG = numel(gi);
    nE = numel(model.CQUAD4.EID);
    ec = nan(nE, 1);
    Dx = zeros(1, nG); Dy = Dx; Dz = Dx;
    
    cleanupObj = onCleanup(@() i_finalize(writer));
    tStart = tic;
    
    for k = 1:nFrames
        % --- displacement ---
        Dx(:) = 0; Dy(:) = 0; Dz(:) = 0;
        Dx(keep_g) = Dx_hist(k, gi(keep_g));
        Dy(keep_g) = Dy_hist(k, gi(keep_g));
        Dz(keep_g) = Dz_hist(k, gi(keep_g));
        model.GRID.Deformation = [Dx; Dy; Dz];
    
        % --- colour ---
        ec(:) = NaN;
        ec(keep_q) = Q_hist(k, qi(keep_q))';
        model.CQUAD4.ElementColor = ec;
    
        % --- refresh ---
        model.update('Scale', p.Results.Scale);
        clim(hAx, cLim);                                 %#ok<CLIM> keep limits fixed after update
        title_h.String = sprintf('%s   t = %.4g s   (frame %d/%d)', ...
            comp, t(t_indices(k)), k, nFrames);
        drawnow;
    
        if p.Results.Pause > 0, pause(p.Results.Pause); end
    
        % --- capture / write ---
        if storeFrames || ~isempty(writer) || isGif
            frame = getframe(hFig);
            if storeFrames
                frames(k) = frame;
            end
            if ~isempty(writer)
                writeVideo(writer, frame);
            elseif isGif
                [A, map] = rgb2ind(frame.cdata, 256);
                if k == 1
                    imwrite(A, map, outFile, 'gif', ...
                        'LoopCount', Inf, 'DelayTime', 1/p.Results.FrameRate);
                else
                    imwrite(A, map, outFile, 'gif', ...
                        'WriteMode', 'append', 'DelayTime', 1/p.Results.FrameRate);
                end
            end
        end
    end
    
    elapsed = toc(tStart);
    fprintf('Done. %.2f s elapsed (%.1f fps render).\n', elapsed, nFrames/elapsed);
    if ~isempty(outFile)
        fprintf('Animation written to: %s\n', outFile);
    end
    
    end
    
    % =========================================================================
    function i_finalize(writer)
    %i_finalize Closes the video writer no matter how the function exits
    %(early error, user Ctrl-C, normal completion).
    if ~isempty(writer)
        try
            close(writer);
        catch
            % already closed or never opened — ignore
        end
    end
    end