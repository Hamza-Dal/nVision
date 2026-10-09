function lim_FD = calc_FD ( data)
    %data = data(1:400);
    data = data ./ max(data);
    n=size(data, 2);
 
    step = n/2;
    
    NUM_ITERATIONS = floor(log2(step)-3);
    length = zeros(NUM_ITERATIONS, 1);
    FD = zeros(NUM_ITERATIONS, 1);
    step_size = zeros(NUM_ITERATIONS, 1);
    
    
    for iteration=1:NUM_ITERATIONS
        
        step = floor(step/2);
        %disp(step);
        
        length(iteration) = 0;
        index = 1;
        
        while (index < n)
            x_length = 1;
            
            while ( abs (  i*x_length/n + data(index)  - data(index+x_length ))  < step/n && index + x_length< n)
                
                %disp ( abs (  i*x_length  + data(index)  - data(index+x_length )));

                x_length = x_length + 1;
            end

            index = index + x_length;
            
            length(iteration) = length(iteration) + 1;
       
        end
        
        FD(iteration) = length(iteration);
        
        step_size(iteration) = step;
        %disp(length(iteration)   );
        
    end

    ft_ = fittype('poly1');

    % Fit this model using new data
    cf_ = fit(step_size, FD, ft_);
    
    lim_FD = cf_.p1;
    
    %figure; plot(step_size, FD);
end