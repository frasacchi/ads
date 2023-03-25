function model = sol103(bin_folder,modeshape_num,varargin)

    p = inputParser();
    p.addParameter('Animate',true,@(x)islogical(x));
    p.parse(varargin{:});
    
    close all
    model = mni.import_matran(fullfile(bin_folder,'Source','sol103.bdf'));
    model.draw;

    % get modal data
    f06 = mni.result.f06(fullfile(bin_folder,'bin','sol103.f06'));
    res_modeshape = f06.read_modeshapes;
    res_freq = f06.read_modes;
    %% apply deformation result
    [~,i] = ismember(model.GRID.GID,res_modeshape.GID(modeshape_num,:));
    model.GRID.Deformation = [res_modeshape.T1(modeshape_num,i);...
        res_modeshape.T2(modeshape_num,i);res_modeshape.T3(modeshape_num,i)];

    model.update()
    if p.Results.Animate
        model.animate('Period',0.5,'Cycles',5,'Scale',0.2) 
    end
end