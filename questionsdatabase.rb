require 'sqlite3'
require 'singleton'

class QuestionsDBConnection < SQLite3::Database 
  include Singleton 
  
  def initialize 
      super('questions.db')
      self.type_translation = true 
      self.results_as_hash = true 
  end 
end 

class User 
  attr_accessor :fname, :lname
  
  def self.all
    data = QuestionsDBConnection.instance.execute("SELECT * FROM users")
    data.map { |user| User.new(user) }
  end 
  
  def initialize(options)
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end 
  
  def self.find_by_id(id)
    user = QuestionsDBConnection.instance.execute(<<-SQL, id)
      SELECT 
        *
      FROM 
        users 
      WHERE 
        id = ?
    SQL
    User.new(user[0])
  end 
  
  def self.find_by_name(fname, lname)
    user = QuestionsDBConnection.instance.execute(<<-SQL, fname, lname)
      SELECT 
        *
      FROM 
        users 
      WHERE 
        fname = ?, lname = ?
    SQL
    User.new(user[0])
  end
  
  def authored_questions
    Question.find_by_author_id(@id)
  end 
  
  def authored_replies
    Reply.find_by_user_id(@id)
  end
  
  def liked_questions
    QuestionLike.liked_questions_for_user_id(@id)
  end 
  
  def followed_questions
    QuestionFollow.followed_questions_for_user_id(@id)
  end 
end

class Question
  attr_accessor :title, :body, :user_id
  
  def self.all
    data = QuestionsDBConnection.instance.execute("SELECT * FROM questions")
    data.map { |datum| Question.new(datum) }
  end 
  
  def initialize(options)
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @user_id = options['user_id']
  end
  
  def self.find_by_id(id)
    question = QuestionsDBConnection.instance.execute(<<-SQL, id)
      SELECT 
        *
      FROM 
        questions 
      WHERE 
        id = ?
    SQL
    Question.new(question[0])
  end 
  
  def self.find_by_author_id(user_id)
    result = QuestionsDBConnection.instance.execute(<<-SQL, user_id)
      SELECT 
        * 
      FROM 
        questions 
      WHERE 
        user_id = ?
    SQL
    Question.new(result[0])
  end 
  
  def author
    @user_id
  end
  
  def likers 
    QuestionLike.likers_for_question_id(@id)
  end 
  
  def num_likes 
    QuestionLike.num_likes_for_question_id(@id)
  end 
  
  def replies
    Reply.find_by_question_id(@id)
  end
  
  def followers
    QuestionFollow.followers_for_question_id(@id)
  end 
  
end

class QuestionFollow
  attr_accessor :user_id, :question_id
  attr_reader :id
  
  def self.all
    data = QuestionsDBConnection.instance.execute("SELECT * FROM question_follows")
    data.map { |datum| QuestionFollow.new(datum) }
  end
  
  def initialize(options)
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
  
  def self.most_followed_questions(n)
    result = QuestionsDBConnection.instance.execute(<<-SQL, n)
      SELECT 
        * 
      FROM 
        questions
      JOIN  
        question_follows ON questions.id = question_follows.question_id
      GROUP BY
        questions.id
      ORDER BY 
        COUNT(question_follows.question_id) DESC 
      LIMIT ?
    SQL
    
  end 
  
  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
  end 
  
  def self.followers_for_question_id(question_id)
    result = QuestionsDBConnection.instance.execute(<<-SQL, question_id)
    SELECT
      users.id, lname, fname 
    FROM
      users
    LEFT OUTER JOIN 
      question_follows ON users.id = question_follows.user_id
    -- JOIN 
    --   questions ON questions.id = question_follows.question_id
    WHERE
      question_id = ?
    SQL
    result.map { |res| User.new(res) }
  end
  
  def self.followed_questions_for_user_id(user_id)
    result = QuestionsDBConnection.instance.execute(<<-SQL, user_id)
    SELECT 
      questions.id, title, body, questions.user_id
    FROM 
      questions 
    JOIN  
      question_follows ON questions.id = question_follows.question_id
    WHERE 
      question_follows.user_id = ? 
    SQL
    result.map { |res| Question.new(res) }
  end 
end

class Reply
  attr_accessor :question_id, :parent_id, :user_id, :body
  attr_reader :id
  
  def self.all
    data = QuestionsDBConnection.instance.execute("SELECT * FROM replies")
    data.map { |datum| Reply.new(datum) }
  end
  
  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @parent_id = options['parent_id']
    @user_id = options['user_id']
    @body = options['body']
  end
  
  def self.find_by_question_id(id)
    reply = QuestionsDBConnection.instance.execute(<<-SQL, id)
      SELECT 
        *
      FROM 
        replies 
      WHERE 
        id = ?
    SQL
    Question.new(reply[0])
  end 
  
  def self.find_by_user_id(user_id)
    result = QuestionsDBConnection.instance.execute(<<-SQL, user_id)
      SELECT 
        * 
      FROM 
        replies 
      WHERE 
        user_id = ?
    SQL
    Reply.new(result[0])
  end 
  
  def self.find_by_user_id(question_id)
    result = QuestionsDBConnection.instance.execute(<<-SQL, question_id)
      SELECT 
        * 
      FROM 
        replies 
      WHERE 
        question_id = ?
    SQL
    Reply.new(result[0])
  end 
  
  def author
    @user_id
  end
  
  def question
    @question_id
  end
  
  def parent_reply
    parent_reply = QuestionsDBConnection.instance.execute(<<-SQL, parent_id)
      SELECT 
        *
      FROM 
        replies 
      WHERE 
        id = ?
    SQL
    Reply.new(parent_reply[0])
  end
  
  
  def child_replies
    child_replies = QuestionsDBConnection.instance.execute(<<-SQL, id)
      SELECT 
        *
      FROM 
        replies
      WHERE 
        parent_id = ?
    SQL
    
    child_replies.map do |rep|
      Reply.new(rep)
    end
  end
end


class QuestionLike
  attr_accessor :question_id, :user_id
  
  def self.all
    data = QuestionsDBConnection.instance.execute("SELECT * FROM question_likes")
    data.map { |datum| QuestionLike.new(datum) }
  end
  
  def initialize(options)
    @id = options['id']
    @question_id = options['question_id']
    @user_id = options['user_id']
  end
  
  def self.likers_for_question_id(question_id)
    result = QuestionsDBConnection.instance.execute(<<-SQL, question_id)
    SELECT
      *
    FROM
      users
    JOIN
      question_likes ON users.id = question_likes.user_id
    WHERE
      question_id = ?
    SQL
    result.map { |res| User.new(res) }
  end
  
  def self.num_likes_for_question_id(question_id)
    result = QuestionsDBConnection.instance.execute(<<-SQL, question_id)
      SELECT
        COUNT(*)
      FROM
        users
      JOIN
        question_likes ON users.id = question_likes.user_id
      WHERE
        question_id = ?
      SQL
    result[0]["COUNT(*)"]
  end
  
  def self.liked_questions_for_user_id(user_id)
    result = QuestionsDBConnection.instance.execute(<<-SQL, user_id)
      SELECT
        *
      FROM
        questions
      JOIN
        question_likes ON questions.id = question_likes.question_id  
      WHERE
        question_likes.user_id = ?
      SQL
    result.map { |ques| Question.new(ques) }
  end 
  
  def self.most_liked_questions(n)
    result = QuestionsDBConnection.instance.execute(<<-SQL, n)
      SELECT 
        * 
      FROM 
        questions
      JOIN  
        question_likes ON questions.id = question_likes.question_id
      GROUP BY
        questions.id
      ORDER BY 
        COUNT(question_likes.question_id) DESC 
      LIMIT ?
    SQL
    result.map { |res| Question.new(res) }
  end 
  
  def self.find_by_id(id)
    question_like = QuestionsDBConnection.instance.execute(<<-SQL, id)
      SELECT 
        *
      FROM 
        question_likes 
      WHERE 
        id = ?
    SQL
    QuestionLike.new(question_like[0])
  end 
end