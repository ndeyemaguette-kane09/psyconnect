package com.example.paymentservice.service;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

import com.example.paymentservice.client.WalletClient;
import com.example.paymentservice.entity.Payment;
import com.example.paymentservice.entity.PaymentStatus;
import com.example.paymentservice.entity.WalletOperation;
import com.example.paymentservice.entity.WalletOperationStatus;
import com.example.paymentservice.entity.WalletOperationType;
import com.example.paymentservice.repository.PaymentRepository;
import com.example.paymentservice.repository.WalletOperationRepository;

@Service
public class WalletOutbox {

    private static final Logger LOGGER = LoggerFactory.getLogger(WalletOutbox.class);

    // un paiement encore PENDING après ce délai n'a pas abouti (crash entre deux étapes)
    private static final long STUCK_PAYMENT_MINUTES = 2;
    private static final long MAX_RETRY_DELAY_SECONDS = 600;

    private final WalletOperationRepository walletOperationRepository;
    private final PaymentRepository paymentRepository;
    private final WalletClient walletClient;
    private final TransactionTemplate transactionTemplate;

    public WalletOutbox(
            WalletOperationRepository walletOperationRepository,
            PaymentRepository paymentRepository,
            WalletClient walletClient,
            PlatformTransactionManager transactionManager
    ) {
        this.walletOperationRepository = walletOperationRepository;
        this.paymentRepository = paymentRepository;
        this.walletClient = walletClient;
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    // statut du paiement et opération à rejouer sont enregistrés ensemble, ou pas du tout
    public WalletOperation failAndScheduleReversal(Payment payment) {
        return transactionTemplate.execute(status -> {
            payment.setStatus(PaymentStatus.FAILED);
            paymentRepository.save(payment);

            WalletOperation operation = newOperation(WalletOperationType.REVERSE_DEBIT, payment);
            operation.setOperationKey("reverse-" + payment.getWalletOperationKey());
            operation.setTargetOperationKey(payment.getWalletOperationKey());
            return walletOperationRepository.save(operation);
        });
    }

    public List<WalletOperation> refundAndScheduleCredits(List<Payment> payments) {
        return transactionTemplate.execute(status -> {
            List<WalletOperation> operations = new ArrayList<>();
            for (Payment payment : payments) {
                payment.setStatus(PaymentStatus.REFUNDED);
                paymentRepository.save(payment);

                WalletOperation operation = newOperation(WalletOperationType.CREDIT, payment);
                operation.setOperationKey("refund-" + payment.getId());
                operation.setAmount(payment.getAmount());
                operations.add(walletOperationRepository.save(operation));
            }
            return operations;
        });
    }

    public boolean tryProcess(WalletOperation operation) {
        try {
            if (operation.getType() == WalletOperationType.REVERSE_DEBIT) {
                walletClient.reverseDebit(operation.getPatientId(), operation.getTargetOperationKey());
            } else {
                walletClient.credit(
                        operation.getPatientId(),
                        operation.getAmount().doubleValue(),
                        operation.getOperationKey()
                );
            }
            operation.setStatus(WalletOperationStatus.DONE);
            operation.setDoneAt(LocalDateTime.now());
            operation.setLastError(null);
            walletOperationRepository.save(operation);
            return true;
        } catch (RuntimeException ex) {
            int attempts = operation.getAttempts() + 1;
            long delay = Math.min(MAX_RETRY_DELAY_SECONDS, 15L * (1L << Math.min(attempts, 10)));
            operation.setAttempts(attempts);
            operation.setNextAttemptAt(LocalDateTime.now().plusSeconds(delay));
            operation.setLastError(truncate(ex.getMessage()));
            walletOperationRepository.save(operation);
            LOGGER.warn("Opération {} non aboutie (tentative {}), nouvel essai dans {} s",
                    operation.getOperationKey(), attempts, delay);
            return false;
        }
    }

    @Scheduled(fixedDelayString = "${payment.outbox.poll-ms:30000}")
    public void processDueOperations() {
        walletOperationRepository
                .findByStatusAndNextAttemptAtBefore(WalletOperationStatus.PENDING, LocalDateTime.now())
                .forEach(this::tryProcess);
    }

    @Scheduled(fixedDelayString = "${payment.saga.recovery-ms:60000}")
    public void recoverStuckPayments() {
        paymentRepository
                .findByStatusAndCreatedAtBefore(
                        PaymentStatus.PENDING,
                        LocalDateTime.now().minusMinutes(STUCK_PAYMENT_MINUTES))
                .forEach(payment -> {
                    LOGGER.warn("Paiement {} resté en attente : annulation du débit", payment.getId());
                    tryProcess(failAndScheduleReversal(payment));
                });
    }

    private WalletOperation newOperation(WalletOperationType type, Payment payment) {
        WalletOperation operation = new WalletOperation();
        operation.setType(type);
        operation.setStatus(WalletOperationStatus.PENDING);
        operation.setPatientId(payment.getPatientId());
        operation.setPaymentId(payment.getId());
        operation.setNextAttemptAt(LocalDateTime.now());
        return operation;
    }

    private String truncate(String message) {
        if (message == null) return null;
        return message.length() > 500 ? message.substring(0, 500) : message;
    }
}
