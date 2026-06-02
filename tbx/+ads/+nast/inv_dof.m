% function inv_dof = inv_dof(dof)
%     dof =num2str(dof);
%     inv_dof = '';
%     for i=1:6
%         if ~contains(dof,num2str(i))
%             inv_dof = [inv_dof,num2str(i)];
%         end
%     end
%     inv_dof = str2num(inv_dof);
% end

function inv_dof = inv_dof(dof,opts)
arguments
    dof 
    opts.con = 123456; 
end
    dof = num2str(dof);
    inv_dof = num2str(opts.con);

    % Iterate through each DOF specified for removal
    for i = 1:length(dof)
        inv_dof = erase(inv_dof, dof(i));
    end
    if isempty(inv_dof)
        inv_dof = []; % Return empty if no DOFs remain
    else
        inv_dof = str2num(inv_dof);
    end
end