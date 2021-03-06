function [pred_table_out,tau,LL_distance] = hmm_novelty(mydata, epochs, model, K, dim, antitype, starttype, max_EM, U)
% 'model' can be clustered, EM or EBW

N = size(mydata,1);
actions_all = unique(cell2mat(mydata(:,1)));
nact_all = numel(actions_all);

pred_table_out = [];
tau = [];
LL_distance = [];

for ep=1:epochs
    permu = reshape(actions_all(randsample(nact_all,nact_all)),[3 5]);
    for rep=1:5
        fprintf('Epoch %d, repetition %d\n',ep,rep);
        leaveout = permu(:,rep);
        [known new] = split_index(N,'novelty',mydata,leaveout);
    
        for i=1:3
            [train test train_new] = split_set(mydata, 'novelty', i, known, new);
            [train, test, train_new] = pca_adjust(train, test, dim, false, train_new);
            [A mu Sigma actions] = models_init(train, K, starttype);
        
            % Train models
            switch model
                case 'clustered'
                
                case 'EM'
                    [A mu Sigma opt_iter] = train_optimal('EM', train, K, starttype, max_EM, false);
                
                case 'EBW'
                    [A mu Sigma opt_iter] = train_optimal('EBW', train, K, starttype, max_EM, false, U);
        
            end
        
            % Decode
            [ LL_frame_train ] = frame_lik(train, A, mu, Sigma);
            [ LL_frame_train_new ] = frame_lik(train_new, A, mu, Sigma);
        
            % Train antimodels
            [A_anti] = train_anti(train, A, mu, Sigma, actions, antitype, LL_frame_train);
        
            % Process anti-models
            [ LL_anti ] = process_anti( [train; train_new], [LL_frame_train LL_frame_train_new], antitype, A_anti, mu, Sigma, K);
        
            % Determine tau
            [pred_table precision] = classify([train ; train_new], actions, LL_anti);
            [confusion_novel1, tau1, error] = determine_tau(pred_table, false, antitype);
        
            % Evaluate testset performance
            [ LL_test ] = frame_lik(test, A, mu, Sigma);
            [ LL_test ] = process_anti(test, LL_test, antitype, A_anti, mu, Sigma, K);
            [pred_table precision confusion_novel2] = classify(test, actions, LL_test, antitype, tau1);
        
            pred_table_out = cat(1,pred_table_out,pred_table);
            tau = cat(2,tau,tau1);
            LL_distance = cat(2,LL_distance,LL_test);
        end
    end
end
end

