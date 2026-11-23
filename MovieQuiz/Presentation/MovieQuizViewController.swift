import UIKit

final class MovieQuizViewController: UIViewController, QuestionFactoryDelegate {

    // MARK: - Private Properties

    private var currentQuestionIndex = 0
    private var correctAnswers = 0
    private let questionsAmount: Int = 10
    private let statisticService: StatisticServiceProtocol = StatisticService()
    private var questionFactory: QuestionFactoryProtocol?
    private var currentQuestion: QuizQuestion?
    private var alertPresenter = AlertPresenter()

    // MARK: - IBOutlets

    @IBOutlet private weak var imageView: UIImageView!
    @IBOutlet private weak var counterLabel: UILabel!
    @IBOutlet private weak var textLabel: UILabel!
    @IBOutlet private weak var noButton: UIButton!
    @IBOutlet private weak var yesButton: UIButton!

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let factory = QuestionFactory()
        factory.delegate = self
        questionFactory = factory

        questionFactory?.requestNextQuestion()
    }

    // MARK: - QuestionFactoryDelegate

    func didReceiveNextQuestion(question: QuizQuestion?) {
        guard let question = question else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.currentQuestion = question
            let step = self.convert(model: question)
            self.show(quiz: step)
        }
    }

    // MARK: - IBActions

    @IBAction private func yesButtonClicked(_ sender: UIButton) {
        guard let currentQuestion = currentQuestion else {
            return
        }

        showAnswerResult(isCorrect: currentQuestion.correctAnswer)
    }

    @IBAction private func noButtonClicked(_ sender: UIButton) {
        guard let currentQuestion = currentQuestion else {
            return
        }

        showAnswerResult(isCorrect: !currentQuestion.correctAnswer)
    }

    // MARK: - Quiz Logic

    private func showAnswerResult(isCorrect: Bool) {
        yesButton.isEnabled = false
        noButton.isEnabled = false

        imageView.layer.borderWidth = 8
        imageView.layer.cornerRadius = 20
        imageView.layer.masksToBounds = true

        if isCorrect {
            correctAnswers += 1
            imageView.layer.borderColor = UIColor.ypGreen.cgColor
        } else {
            imageView.layer.borderColor = UIColor.ypRed.cgColor
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else {
                return
            }

            self.showNextQuestionOrResults()
        }
    }

    private func showNextQuestionOrResults() {
        if currentQuestionIndex == questionsAmount - 1 {
            statisticService.store(correct: correctAnswers, total: questionsAmount)

            let text = correctAnswers == questionsAmount
            ? "Поздравляем, вы ответили на \(questionsAmount) из \(questionsAmount)!"
            : "Вы ответили на \(correctAnswers) из \(questionsAmount), попробуйте ещё раз!"

            let result = QuizResultsViewModel(
                title: "Этот раунд окончен!",
                text: text,
                buttonText: "Сыграть ещё раз"
            )

            show(quiz: result)
        } else {
            currentQuestionIndex += 1
            questionFactory?.requestNextQuestion()
        }
    }

    // MARK: - View Model Conversion

    private func convert(model: QuizQuestion) -> QuizStepViewModel {
        QuizStepViewModel(
            imageName: UIImage(named: model.imageName) ?? UIImage(),
            question: model.text,
            questionNumber: "\(currentQuestionIndex + 1)/\(questionsAmount)"
        )
    }

    // MARK: - UI Updates

    private func show(quiz step: QuizStepViewModel) {
        imageView.image = step.imageName
        textLabel.text = step.question
        counterLabel.text = step.questionNumber

        imageView.layer.borderWidth = 0
        yesButton.isEnabled = true
        noButton.isEnabled = true
    }

    private func show(quiz result: QuizResultsViewModel) {
        let bestGame = statisticService.bestGame

        let message = """
        \(result.text)
        Количество сыгранных квизов: \(statisticService.gamesCount)
        Рекорд: \(bestGame.correct)/\(bestGame.total) (\(bestGame.date.dateTimeString))
        Средняя точность: \(String(format: "%.2f", statisticService.totalAccuracy))%
        """

        let model = AlertModel(
            title: result.title,
            message:  message,
            buttonText: result.buttonText
        ) { [weak self] in
            guard let self = self else { return }

            self.currentQuestionIndex = 0
            self.correctAnswers = 0
            self.questionFactory?.requestNextQuestion()
        }

        alertPresenter.show(in: self, model: model)
    }
}
