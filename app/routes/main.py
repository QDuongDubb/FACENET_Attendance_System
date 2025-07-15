from flask import Blueprint, render_template, redirect, url_for
from flask_login import login_required, current_user

main = Blueprint('main', __name__)

@main.route('/')
def index():
    return render_template('index.html', title='Home')

@main.route('/dashboard')
@login_required
def dashboard():
    return render_template('dashboard.html', title='Teacher Dashboard', teacher=current_user)