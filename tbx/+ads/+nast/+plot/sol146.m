function model = sol146(bin_folder, varargin)
    %SOL146 Loads a NASTRAN SOL 146 (transient/gust) model and applies the
    %dynamic results to the bulk model for visualisation. Analogous to
    %`sol144` but uses the HDF5 result file (`.h5`) instead of the `.f06`
    %since dynamic responses are time-histories that compress better and
    %parse faster from HDF5.
    %
    % Inputs:
    %   - bin_folder : char vector. Project folder containing:
    %                   <bin_folder>/Source/sol146.bdf
    %                   <bin_folder>/bin/sol146.h5
    %
    % Optional name-value pairs:
    %   - 'Subcase'        : int. Which subcase to display (default 1).
    %   - 'TimeIndex'      : int. Which time station to display. Default []
    %                        which picks the time of peak |Z-displacement|.
    %   - 'ForceComponent' : char. Which QUAD4 force quantity to colour by.
    %                        One of: 'Mx','My','Mxy','Nx','Ny','Nxy','Fx','Fy'.
    %                        Default 'Mx'.
    %   - 'Envelope'       : logical. If true, colour by max |component| over
    %                        the whole time history (ignores TimeIndex for the
    %                        color, but still uses TimeIndex for the deformed
    %                        shape). Default false.
    %
    % Example:
    %   m = sol146('C:\...\ex_ffwt_sol146');
    %   m = sol146('C:\...\ex_ffwt_sol146', 'ForceComponent','My','Envelope',true);
    
    arguments
        bin_folder char
    end
    arguments (Repeating)
        varargin
    end
    
    p = inputParser();
    p.addParameter('Subcase',        1,    @(x)isnumeric(x)&&isscalar(x));
    p.addParameter('TimeIndex',      [],   @(x)isempty(x)||(isnumeric(x)&&isscalar(x)));
    p.addParameter('ForceComponent', 'Mx', @ischar);
    p.addParameter('Envelope',       false, @islogical);
    p.parse(varargin{:});
    
    % ---- import & draw the model ----
    bdf_path = fullfile(bin_folder, 'Source', 'sol146.bdf');
    h5_path  = fullfile(bin_folder, 'bin',    'sol146.h5');
    model = mni.import_matran(bdf_path, 'ExpandInclude', true);
    model.draw;
    
    % ---- read dynamic results ----
    hdf = mni.result.hdf5(h5_path);
    res = hdf.read_dynamic();
    if isempty(res)
        warning('sol146:NoResults','No results found in %s', h5_path);
        return
    end
    
    % ---- pick the subcase ----
    sc_idx = p.Results.Subcase;
    if sc_idx < 1 || sc_idx > numel(res)
        error('sol146:BadSubcase','Subcase %d requested but only %d available.', sc_idx, numel(res));
    end
    sub = res(sc_idx);
    fprintf('SOL 146 results: %d subcase(s), using subcase %d (ID=%d, %d time steps)\n', ...
        numel(res), sc_idx, sub.Subcase, numel(sub.t));
    
    % ---- pick the time index ----
    if isempty(p.Results.TimeIndex)
        if ~isempty(sub.Displacement)
            [~, t_idx] = max(max(abs(sub.Displacement.Z), [], 2));
        else
            t_idx = numel(sub.t);
        end
    else
        t_idx = p.Results.TimeIndex;
    end
    fprintf('Displaying t-index %d  (t = %.6g s)\n', t_idx, sub.t(t_idx));
    
    % ---- apply displacement at chosen time step ----
    if ~isempty(sub.Displacement)
        [~, gi] = ismember(model.GRID.GID, sub.Displacement.IDs);
        keep = gi > 0;
        Dx = zeros(1, numel(gi)); Dy = Dx; Dz = Dx;
        Dx(keep) = sub.Displacement.X(t_idx, gi(keep));
        Dy(keep) = sub.Displacement.Y(t_idx, gi(keep));
        Dz(keep) = sub.Displacement.Z(t_idx, gi(keep));
        model.GRID.Deformation = [Dx; Dy; Dz];
    end
    
    % ---- apply QUAD4 forces ----
    if isfield(sub, 'Quad4Force') && ~isempty(sub.Quad4Force) && isprop(model, 'CQUAD4')
        Q    = sub.Quad4Force;
        comp = p.Results.ForceComponent;
        if ~isfield(Q, comp)
            error('sol146:BadComponent', ...
                'Unknown ForceComponent ''%s''. Must be one of Nx/Ny/Nxy/Mx/My/Mxy/Fx/Fy.', comp);
        end
        if p.Results.Envelope
            vals = max(abs(Q.(comp)), [], 1);    % 1 x nQuad
        else
            vals = Q.(comp)(t_idx, :);           % 1 x nQuad
        end
        % map element values onto the model's CQUAD4 elements
        [~, qi] = ismember(model.CQUAD4.EID, Q.EIDs);
        keep = qi > 0;
        ec = nan(numel(model.CQUAD4.EID), 1);
        ec(keep) = vals(qi(keep))';
        model.CQUAD4.ElementColor = ec;
        if p.Results.Envelope
            model.CQUAD4.ColorLabel = sprintf('max |%s| over time', comp);
        else
            model.CQUAD4.ColorLabel = sprintf('%s @ t = %.4g s', comp, sub.t(t_idx));
        end
    end
    
    % ---- refresh the figure ----
    model.update('Scale', 1);
    
    % ---- nice-to-have: diverging colormap + colorbar with the label ----
    ax = gca;
    try
        colormap(ax, parula);   % swap to e.g. turbo or a diverging map if preferred
        cb = colorbar(ax);
        if isprop(model, 'CQUAD4') && ~isempty(model.CQUAD4.ColorLabel)
            cb.Label.String = model.CQUAD4.ColorLabel;
        end
    catch
        % colorbar may fail on headless / unusual axes -- ignore
    end
    end